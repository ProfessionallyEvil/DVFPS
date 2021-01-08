extends Node

# -----
# Helpers
# -----
func is_server():
	return get_tree().get_rpc_sender_id() == 1

# -----
# Server RPC Functions - these will execute on the server
# -----
remote func init_level_client_callback(id: int) -> void:
	# This is a callback RPC function that the client will use to notify the server
	# that it has initialized the level specified by the server.
	print("client ", id, " has initialized the level")
	# initialize the main player character
	# TODO this will have to be factored out to allow initilzation of all players to all other players.
	create_player() # make a player on the server
	self.init_player_handler(id)

# This will get invoked by nodes in the client to allow for the node paths to match up
func init_level_client_callback_handler(id: int) -> void:
	# invoke the "init_level_client_callback" RPC on the server from the client
	rpc_id(1, "init_level_client_callback", id)

remote func push_client_message(message: Dictionary) -> void:
	var message_type: String = message.get("message_type", null)
	# print(message)
	match message_type:
		"input_action":
			get_node("/root/Main/InputQueue").push_message(message)
		_: return

func push_client_message_handler(message: Dictionary) -> void:
	rpc_id(1, "push_client_message", message)

# -----
# Client RPC Functions - these will execute on the client
# These should only be called by the server, a naive protection is to check if
# the rpc_caller_id is 1, but in theory this can be spoofed without encrypiton!
# -----
remote func init_level(level_data) -> void:
	# The server will call this function against a given client to tell it
	# what level to initialize.
	print("init_level called by ", get_tree().get_rpc_sender_id())
	if get_tree().get_rpc_sender_id() != 1:
		return
	print("init_level called")
	var id = get_tree().get_rpc_sender_id()
	print(level_data)
	var scene_manager: Node = get_node("SceneManager")
	var new_level: PackedScene = load(level_data["level_scene_path"])
	get_tree().get_root().get_node("Main/SceneManager").add_child(new_level.instance())
	# invoke the server's init_level callback sending the client ID back
	#rpc_id(1, "init_level_client_callback", get_tree().get_network_unique_id())
	init_level_client_callback_handler(get_tree().get_network_unique_id())
	
# Server calls this
func init_level_handler(id: int, level_data: Dictionary) -> void:
	print("telling the client ", id, " what level to init")
	rpc_id(id, "init_level", level_data)

remote func init_player():
	var sender: int = get_tree().get_rpc_sender_id()
	print("sender ", sender)
	if sender != 1:
		return
	print("initializing the player!")
	create_player() # make a player on the client

func create_player():
	var player_character = load("res://Character/Character.tscn")
	player_character = player_character.instance()
	if get_tree().is_network_server():
		player_character.is_player = false
		player_character.is_server_character = true
	player_character.name = str(get_tree().get_network_unique_id())
	get_tree().get_root().get_node("Main/SceneManager").add_child(player_character)

func init_player_handler(id: int):
	rpc_id(id, "init_player")
