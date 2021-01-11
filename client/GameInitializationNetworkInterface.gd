extends Node

var main: Node

func _ready() -> void:
	main = $"/root/Main"

#####################################
# Server Communicates to the client #
#####################################

# -----
# The server will invoke this RPC to tell the client what level to instantiate
# -----
remote func init_level(level_data: Dictionary) -> void:
	# The server will call this function against a given client to tell it
	# what level to initialize.
	if get_tree().get_rpc_sender_id() != 1:
		return
	var id = get_tree().get_rpc_sender_id()
	var scene_manager: Node = get_node("/root/Main/SceneManager")
	var new_level: PackedScene = load(level_data["level_scene_path"])
	get_tree().get_root().get_node("Main/SceneManager").add_child(new_level.instance())
	# invoke the server's init_level callback sending the client ID back
	#rpc_id(1, "init_level_client_callback", get_tree().get_network_unique_id())

# -----
# This is invoked by the server to create a player or puppet_player on this client
# -----
remote func create_player(init_data: Dictionary) -> void:
	#var id: int = get_tree().get_network_unique_id()
	var client_id: int = init_data["client_id"]
	var player_character_scene: PackedScene = load("res://Character/Character.tscn")
	var player_character: Character = player_character_scene.instance()
	if init_data.get("is_puppet", false):
		# this ensures that this particular instance of a Character is only controlled via
		# the puppet_process_input function
		player_character.server_puppet = true
	else:
		player_character.local_player = true
	player_character.name = str(client_id)
	#get_tree().get_root().get_node("Main/SceneManager").add_child(player_character)
	var scene_manager: Node = $"/root/Main/SceneManager"
	scene_manager.add_child(player_character)
	# Here we have to add the character ref to the relevant player info since this doesn't return into
	# the main of the client
	# also this is where we are initializing the player_info
	main.player_info[client_id] = {"character_node": player_character}
