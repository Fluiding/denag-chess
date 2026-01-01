extends PanelContainer

const PORT = 14922
signal init_chess_board(is_white)

func on_player_connect(_id: int):
	global.is_multiplayer = true
	show_chessboard()
	init_chess_board.emit(false)
	%LoadingLabel.text = ""

func on_player_disconnect(_id: int):
	$"../ChessBoard".visible = false
	visible = true

func show_chessboard():
	visible = false
	$"../ChessBoard".visible = true

func host() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, 2)

	multiplayer.multiplayer_peer = peer
	peer.peer_connected.connect(on_player_connect)
	peer.peer_disconnected.connect(on_player_disconnect)

	%LoadingLabel.text = "Waiting for opponent..."

func join() -> void:
	var peer = ENetMultiplayerPeer.new()
	%LoadingLabel.text = "Connecting..."
	var error = peer.create_client(%AddressBox.text, PORT)
	if error:
		%LoadingLabel.text = error
		return

	multiplayer.multiplayer_peer = peer
	peer.peer_disconnected.connect(on_player_disconnect)

	global.is_multiplayer = true
	show_chessboard()
	init_chess_board.emit(true)
	%LoadingLabel.text = ""
