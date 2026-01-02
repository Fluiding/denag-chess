extends PanelContainer

const default_board = [
	["BlackRook1", "BlackKnight1", "BlackBishop1", "BlackQueen", "BlackKing", "BlackBishop2", "BlackKnight2", "BlackRook2"],
	["BlackPawn1", "BlackPawn2", "BlackPawn3", "BlackPawn4", "BlackPawn5", "BlackPawn6", "BlackPawn7", "BlackPawn8"],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	["WhitePawn1", "WhitePawn2", "WhitePawn3", "WhitePawn4", "WhitePawn5", "WhitePawn6", "WhitePawn7", "WhitePawn8"],
	["WhiteRook1", "WhiteKnight1", "WhiteBishop1", "WhiteQueen", "WhiteKing", "WhiteBishop2", "WhiteKnight2", "WhiteRook2"],
]

const piece_directions = {
	rook = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(0, -1)
	],
	bishop = [
		Vector2i(1, 1), Vector2i(-1, 1),
		Vector2i(1, -1), Vector2i(-1, -1)
	],
	knight = [
		Vector2i(1, 2), Vector2i(-1, 2),
		Vector2i(1, -2), Vector2i(-1, -2),
		Vector2i(2, 1), Vector2i(-2, 1),
		Vector2i(2, -1), Vector2i(-2, -1)
	],
}

enum PieceType {Rook, Knight, Bishop, Queen, King, Pawn}
const horizontal_squares = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
var mouse_on_square
var holding_piece: Piece
var pieces = {}
var regex = RegEx.new()
var is_player_white: bool
var is_turn = false

class Piece:
	var type: PieceType
	var is_white: bool
	var in_check: bool = false # Only for the king pieces
	var position: String
	var moves: int = 0
	var node: Node

	## Instantiate a Piece object, duplicate a piece node, and make
	## its parent the square node of the notation argument given.
	func _init(this, _type: PieceType, _is_white, node_name, notation):
		type = _type
		is_white = _is_white
		position = notation
		node = this.get_node("Assets/%s" % node_name).duplicate()
		this.get_square(notation).add_child(node)
		node.visible = true

func _ready():
	# To derive piece info from the name of a piece.
	regex.compile("[A-Z][a-z]*")
	init_chess_board(global.is_white)

func _process(_delta: float):

	if Input.is_action_just_pressed("click") and mouse_on_square:
		var piece = get_piece_on_square(mouse_on_square)
		if piece and piece.is_white == is_player_white:
			holding_piece = piece
			piece.node.z_index += 1

	if holding_piece:
		var mouse_pos = get_global_mouse_position()
		var target_piece_pos = mouse_pos - holding_piece.node.size / 2
		holding_piece.node.global_position = target_piece_pos
		if holding_piece.in_check:
			var check_ind = holding_piece.node.get_parent()
			check_ind = check_ind.get_node("CheckIndicator")
			var target_ind_pos = mouse_pos - check_ind.size / 2
			check_ind.global_position = target_ind_pos



	if Input.is_action_just_released("click") and mouse_on_square and holding_piece:

		if (is_turn or !global.is_multiplayer) \
		and mouse_on_square in get_valid_moves(holding_piece):
			var client_id = multiplayer.get_unique_id()
			move.rpc(holding_piece.node.name, mouse_on_square, client_id)
		else:
			holding_piece.node.position = Vector2.ZERO
			if holding_piece.in_check:
				var check_ind = holding_piece.node.get_parent()
				check_ind = check_ind.get_node("CheckIndicator")
				check_ind.position = Vector2.ZERO
				check_ind.set_anchors_and_offsets_preset(PRESET_CENTER)

		holding_piece.node.z_index -= 1
		holding_piece = null


func init_chess_board(is_white: bool):
	%GameBeginSound.play()
	is_player_white = is_white
	is_turn = !global.is_multiplayer or is_white

	var board = default_board.duplicate(true)
	if !is_white:
		board.reverse()

	for y_index in range(8):
		for x_index in range(8):
			var no = horizontal_squares[x_index] + str(8 - y_index)
			var piece_name = board[y_index][x_index]
			if not piece_name:
				continue

			var data = regex.search_all(piece_name)
			var white = data[0].get_string() == "White"
			var type = data[1].get_string()

			var piece_node = get_node("Assets/%s" % piece_name)
			var piece_obj = Piece.new(self, PieceType[type], white, piece_node.name, no)
			pieces.set(piece_node.name, piece_obj)

# Cast a ray from the piece to detect if squares are valid moves.
func raycast(piece, dir: Vector2i, steps = 32, include_capture = true, captures_only = false):
	var valid_moves = []
	var step = 0
	var pos = get_normalized_pos(piece.position) + dir

	while pos.x > 0 and pos.x < 9 and pos.y > 0 and pos.y < 9 and step < steps:
		var no = get_no_from_norm_pos(pos)
		var piece_on_sq = get_piece_on_square(no)

		if piece_on_sq:
			if piece_on_sq.is_white != piece.is_white and include_capture:
				valid_moves.append(no)
			break
		elif captures_only:
			break

		valid_moves.append(no)
		pos += dir
		step += 1

	return valid_moves


func get_valid_moves(piece):
	var valid_moves = []

	match piece.type:
		PieceType.Rook:
			for dir in piece_directions.rook:
				valid_moves.append_array(raycast(piece, dir))

		PieceType.Knight:
			for dir in piece_directions.knight:
				valid_moves.append_array(raycast(piece, dir, 1))

		PieceType.Bishop:
			for dir in piece_directions.bishop:
				valid_moves.append_array(raycast(piece, dir))

		PieceType.Queen:
			for dir in piece_directions.bishop + piece_directions.rook:
				valid_moves.append_array(raycast(piece, dir))

		PieceType.King:
			for dir in piece_directions.bishop + piece_directions.rook:
				valid_moves.append_array(raycast(piece, dir, 1))

		PieceType.Pawn:
			# Vertical Movement
			var dir
			if global.is_multiplayer:
				dir = Vector2i(0, 1)
			else:
				dir = Vector2i(0, 1 if is_turn else -1)
			var steps = int(piece.moves == 0) + 1

			# Diagonal Captures
			var d1 = Vector2i(dir.y, dir.y)
			var d2 = Vector2i(-dir.y, dir.y)

			valid_moves.append_array(raycast(piece, dir, steps, false))
			valid_moves.append_array(raycast(piece, d1, 1, true, true))
			valid_moves.append_array(raycast(piece, d2, 1, true, true))

	return valid_moves

func set_king_in_check(is_king_white, state):
	var side = "White" if is_king_white else "Black"
	var king = pieces[side + "King"]
	var king_square = get_square(king.position)

	king.in_check = state
	if !state and king_square.has_node("CheckIndicator"):
		king_square.get_node("CheckIndicator").queue_free()
		return

	if state and !king_square.has_node("CheckIndicator"):
		var check_ind = $Assets/CheckIndicator.duplicate()
		king_square.add_child(check_ind)
		check_ind.position = Vector2.ZERO
		check_ind.set_anchors_and_offsets_preset(PRESET_CENTER)
		check_ind.visible = true
		%CheckSound.play()

func handle_checks():
	var white_king = pieces["WhiteKing"]
	var black_king = pieces["BlackKing"]

	for piece in pieces.values():
		if piece.is_white and black_king.position in get_valid_moves(piece):
			return set_king_in_check(false, true)
		if !piece.is_white and white_king.position in get_valid_moves(piece):
			return set_king_in_check(true, true)

	set_king_in_check(false, false)
	set_king_in_check(true, false)


@rpc("any_peer", "call_local", "reliable")
func move(piece_name, no: String, client_id: int):
	if !global.is_multiplayer:
		is_player_white = !is_player_white
	if client_id != multiplayer.get_unique_id():
		no = no[0] + str(9 - int(no[1]))

	var piece = pieces[piece_name]
	var piece_on_sq = get_piece_on_square(no)
	var source_square = get_square(piece.position)
	var target_square = get_square(no)

	source_square.remove_child(piece.node)
	target_square.add_child(piece.node)
	piece.node.position = Vector2.ZERO
	piece.position = no
	piece.moves += 1

	if piece_on_sq:
		piece_on_sq.node.queue_free()
		pieces.erase(pieces.find_key(piece_on_sq))
		%CaptureSound.play()
	else:
		%MoveSound.play()

	if piece.type == PieceType.King and piece.in_check:
		source_square.get_node("CheckIndicator").queue_free()

	handle_checks()
	is_turn = !is_turn


func is_valid_notation(no: String):
	if len(no) == 2 and no[0] in "abcdefgh" and no[1] in "12345678":
		return true
	return false

func get_square(no: String):
	if !is_valid_notation(no):
		return
	return get_node("Squares/%s/%s" % [no[0], no[1]])

func get_normalized_pos(no: String):
	if !is_valid_notation(no):
		return
	var x = horizontal_squares.find(no[0])
	return Vector2i(x + 1, int(no[1]))

func get_no_from_norm_pos(pos: Vector2i):
	if pos.x < 1 or pos.x > 8 or pos.y < 1 or pos.y > 8:
		return
	var x = horizontal_squares[pos.x - 1]
	return x + str(pos.y)

func get_piece_on_square(no: String):
	for piece in pieces.values():
		if piece.position == no:
			return piece
	return

func on_square_mouse_entered(square_node, __):
	mouse_on_square = square_node.get_parent().name + square_node.name

func on_square_mouse_exited() -> void:
	mouse_on_square = null
