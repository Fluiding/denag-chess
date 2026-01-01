extends Control

@onready var current_menu = %MainMenu
@onready var peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	multiplayer.peer_connected.connect(on_player_connect)
	multiplayer.peer_disconnected.connect(on_player_disconnect)
	multiplayer.connected_to_server.connect(client_connected)

func on_exit_pressed():
	get_tree().quit()

func switch_menu(menu: NodePath):
	var menu_name = menu.get_name(menu.get_name_count() - 1)
	var menu_node = get_node("%" + str(menu_name))
	current_menu.visible = false
	menu_node.visible = true
	current_menu = menu_node

func singleplayer():
	global.is_multiplayer = false
	global.is_white = bool(randi() % 2)
	get_tree().change_scene_to_file("res://scenes/chess_board.tscn")

func on_player_connect(_id):
	if multiplayer.is_server():
		%HostingMenuContents/StatusLabel.text = "Loading game..."
		get_tree().change_scene_to_file("res://scenes/chess_board.tscn")

func on_player_disconnect(_id):
	pass

func host(port: int = 14922):
	%HostingMenuContents/StatusLabel.text = "Establishing connection..."

	var err = peer.create_server(port, 2)
	if err:
		%HostingMenuContents/StatusLabel.text = "Could not make connection. (error code %s)" % err
		return err

	multiplayer.multiplayer_peer = peer
	global.is_multiplayer = true
	global.is_white = true
	%HostingMenuContents/StatusLabel.text = "Waiting for opponent..."

func client_connected():
	global.is_multiplayer = true
	global.is_white = false
	get_tree().change_scene_to_file("res://scenes/chess_board.tscn")

func join(port: int = 14922):
	%JoiningMenuContents/StatusLabel.text = "Establishing connection..."

	var address = %JoinMenuContents/AddressInput.text
	if address.is_empty():
		address = "127.0.0.1"

	var err = peer.create_client(address, port)
	if err:
		%JoiningMenuContents/StatusLabel.text = "Could not make connection. (error code %s)" % err
		return err

	%JoiningMenuContents/StatusLabel.text = "Searching for server..."
	multiplayer.multiplayer_peer = peer
	await get_tree().create_timer(5).timeout
	%JoiningMenuContents/StatusLabel.text = "Could not find server."
	cancel_connection()

func cancel_connection():
	multiplayer.multiplayer_peer = null
	peer.close()
	peer = ENetMultiplayerPeer.new()
