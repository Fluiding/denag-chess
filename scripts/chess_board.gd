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
var is_white: bool
var is_playing_side: bool = true
var is_turn: bool = false

class Piece:
	var type: PieceType
	var is_white: bool
	var position: String
	var moves: int = 0
	var node: Node

	## Create a Piece object and set the nodes inside /Pieces/
	## to the position according to the notation argument given.
	func _init(this, _type: PieceType, _is_white, node_name, notation):
		type = _type
		is_white = _is_white
		position = notation
		node = this.get_node("Pieces/%s" % node_name).duplicate()
		this.get_square(notation).add_child(node)
		node.visible = true

func _init() -> void:
	regex.compile("[A-Z][a-z]*")

func _ready() -> void:
	init_chess_board(global.is_white)

func _process(_delta: float) -> void:
	if holding_piece:
		var mouse_pos = get_global_mouse_position()
		var target_pos = mouse_pos - holding_piece.node.size / 2
		holding_piece.node.global_position = target_pos

	if Input.is_action_just_pressed("click") and mouse_on_square:
		if is_turn or !global.is_multiplayer:
			var piece = get_piece_on_square(mouse_on_square)
			if piece and piece.is_white == is_white:
				holding_piece = piece
				piece.node.z_index = 1

	if Input.is_action_just_released("click") and mouse_on_square and holding_piece:
		if mouse_on_square in get_valid_moves(holding_piece):
			var id = multiplayer.get_unique_id()
			move.rpc(holding_piece.node.name, mouse_on_square, id)
		else:
			var target_pos = get_global_pos(holding_piece.position)
			holding_piece.node.global_position = target_pos

		holding_piece.node.z_index = 0
		holding_piece = null

func init_chess_board(_is_white: bool):
	is_white = _is_white
	is_turn = !global.is_multiplayer or is_white
	var board = default_board.duplicate()
	if is_white:
		board.reverse()

	for y_index in range(8):
		for x_index in range(8):
			var no = horizontal_squares[x_index] + str(y_index + 1)
			var piece_name = board[y_index][x_index]
			if not piece_name:
				continue

			var data = regex.search_all(piece_name)
			var white = data[0].get_string() == "White"
			var type = data[1].get_string()

			var piece_node = get_node("Pieces/%s" % piece_name)
			var piece_obj = Piece.new(self, PieceType[type], white, piece_node.name, no)
			pieces.set(piece_node.name, piece_obj)

func raycast(piece: Piece, dir: Vector2i, steps = 32, include_capture = true):
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

		valid_moves.append(no)
		pos += dir
		step += 1

	return valid_moves

func get_valid_moves(piece: Piece):
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
			var dir
			if global.is_multiplayer:
				dir = Vector2i(0, 1)
			else:
				dir = Vector2i(0, 1 if is_turn else -1)
			var steps = int(piece.moves == 0) + 1
			valid_moves.append_array(raycast(piece, dir, steps, false))

			var origin = get_normalized_pos(piece.position)
			var check1 = get_no_from_norm_pos(origin + Vector2i(dir.y, dir.y))
			var check2 = get_no_from_norm_pos(origin + Vector2i(-dir.y, dir.y))

			if check1 and get_piece_on_square(check1):
				valid_moves.append(check1)
			if check2 and get_piece_on_square(check2):
				valid_moves.append(check2)

	return valid_moves

@rpc("any_peer", "call_local", "reliable")
func move(piece_name: String, no: String, client_id: int):
	is_turn = !is_turn

	if !global.is_multiplayer:
		is_white = !is_white
	if client_id != multiplayer.get_unique_id():
		no = no[0] + str(9 - int(no[1]))

	var piece = pieces[piece_name]
	var piece_on_sq = get_piece_on_square(no)
	var source_square = get_square(piece.position)
	var target_square = get_square(no)

	if piece_on_sq:
		piece_on_sq.node.queue_free()
		pieces.erase(pieces.find_key(piece_on_sq))
		%CaptureSound.play()
	else:
		%MoveSound.play()

	source_square.remove_child(piece.node)
	target_square.add_child(piece.node)
	piece.node.position = Vector2.ZERO
	piece.position = no
	piece.moves += 1

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

func get_global_pos(no: String):
	if !is_valid_notation(no):
		return
	var top_left = $"Squares/a/8".get_global_rect()
	var offset_x = top_left.size.x * horizontal_squares.find(no[0])
	var offset_y = top_left.size.y * 8 - top_left.size.y * int(no[1])
	return top_left.position + Vector2(offset_x, offset_y)

func get_piece_on_square(no: String):
	for piece in pieces.values():
		if piece.position == no:
			return piece
	return

func on_square_mouse_entered(square_node, __):
	mouse_on_square = square_node.get_parent().name + square_node.name

func on_square_mouse_exited() -> void:
	mouse_on_square = null
