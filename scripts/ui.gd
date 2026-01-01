extends Control

@onready var current_menu = %MainMenu

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

func host(port: int = 14922):
	%HostingMenuContents/StatusLabel.text = "Establishing connection..."
	var err = networking.host(port)
	if err:
		%HostingMenuContents/StatusLabel.text = "Could not make connection. (error code %s)" % err
		return err
	%HostingMenuContents/StatusLabel.text = "Waiting for opponent..."

func join(port: int = 14922):
	%JoiningMenuContents/StatusLabel.text = "Establishing connection..."

	var address = %JoinMenuContents/AddressInput.text
	var err = networking.create_client(address, port)
	if err:
		%JoiningMenuContents/StatusLabel.text = "Could not make connection. (error code %s)" % err
		return err

	%JoiningMenuContents/StatusLabel.text = "Searching for server..."
	err = await networking.join()
	%JoiningMenuContents/StatusLabel.text = "Could not find server."
	cancel_connection()

func cancel_connection():
	networking.cancel_connection()
