extends Node

var main: Node

func _ready() -> void:
	main = $"/root/Main"

# -----
# This is called on the server
# This initializes the level on the server
# -----
func init_level(level_data) -> void:
	# set the level here on the server too
	var level: PackedScene = load(level_data["level_scene_path"])
	var scene_manager: Node = $"/root/Main/SceneManager"
	scene_manager.add_child(level.instance())
	#get_node("SceneManager").add_child(level.instance())

# -----
# Update or init the list of player puppets in all connected clients
# -----
func broadcast_player_puppets() -> void:
	# initialize a puppet of this player on the other clients
	for idx in main.player_info:
		var player: Dictionary = main.player_info[idx]
		for idy in main.player_info: 
			if idx != idy:
				print("SENDING CLIENT ID", idx)
				rpc_id(idy, "create_player", {
					"client_id": idx,
					"spawn_point_node_path": "",
					"is_puppet": true
				})
				#self.init_puppet(idy, idx)

func init_client_level(client_id: int, level_data: Dictionary) -> void:
	# tell the client to instantiate the given level
	rpc_id(client_id, "init_level", level_data)

# -----
# Create a player on the server
# -----
func create_player(id: int, is_puppet: bool) -> Character:
	var player_character_scene: PackedScene = load("res://Character/Character.tscn")
	var player_character: Character = player_character_scene.instance()
	if get_tree().is_network_server() or is_puppet:
		# this ensures that this particular instance of a Character is only controlled via
		# the puppet_process_input function
		player_character.server_puppet = true
	else:
		player_character.local_player = true
	player_character.name = str(id)
	get_tree().get_root().get_node("Main/SceneManager").add_child(player_character)
	return player_character
	
# -----
# Tell the given client to instantiate a player or player puppet
# -----
func create_client_player(client_id: int, init_data: Dictionary) -> void:
	rpc_id(client_id, "create_player", init_data)

############################################
# RPC functions that are called by clients #
############################################

# -----
# Clients will invoke this RCP call when they are done initializing the game with a level and a player character
# -----
remote func game_initialization_complete_notification():
	var caller_id: int = get_tree().get_network_unique_id()
	main.player_info[caller_id]["game_initialized"] = true
