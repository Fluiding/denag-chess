extends Node

@onready var peer = ENetMultiplayerPeer.new()
var connected = false

func _ready() -> void:
	multiplayer.peer_connected.connect(on_player_connect)
	multiplayer.peer_disconnected.connect(on_player_disconnect)
	multiplayer.connected_to_server.connect(client_connected)

func on_player_connect(_id):
	if multiplayer.is_server():
		get_tree().change_scene_to_file("res://scenes/chess_board.tscn")

func on_player_disconnect(_id):
	pass

func host(port: int = 14922):
	var err = peer.create_server(port, 2)
	if err:
		return err

	multiplayer.multiplayer_peer = peer
	global.is_multiplayer = true
	global.is_white = true

func client_connected():
	connected = true
	global.is_multiplayer = true
	global.is_white = false
	get_tree().change_scene_to_file("res://scenes/chess_board.tscn")

func create_client(address: String, port: int = 14922):
	connected = false
	if address.is_empty():
		address = "127.0.0.1"
	var err = peer.create_client(address, port)
	return err

func join():
	multiplayer.multiplayer_peer = peer
	await get_tree().create_timer(5).timeout
	if not connected:
		cancel_connection()
		return 1

func cancel_connection():
	multiplayer.multiplayer_peer = null
	peer.close()
	peer = ENetMultiplayerPeer.new()
