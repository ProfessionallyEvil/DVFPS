extends Node

# -----
# Helpers
# -----
func is_server():
	return get_tree().get_rpc_sender_id() == 1

# -----
# THIS IS JUST A TEST CARRY ON
# -----
remote func do_insecure_object_deserialization(obj):
	print("insecure deserialization attempt")
	print(typeof(obj))

# -----
# Server RPC Functions - these will execute on the server
# -----
remote func init_level_client_callback(id: int) -> void:
	# This is a callback RPC function that the client will use to notify the server
	# that it has initialized the level specified by the server.
	print("client ", id, " has initialized the level")
	# initialize the main player character
	# TODO this will have to be factored out to allow initilzation of all players to all other players.
	var character_ref: Character = create_player(id) # make a player on the server
	# stuff a reference to the player in the correct entry in player_info
	var main: Node = $"/root/Main"
	if main.player_info.get(id, null):
		main.player_info[id]["character_node"] = character_ref
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
			# get_node("/root/Main/InputQueue").push_message(message)
			# more spaghetti code
			var main = $"/root/Main"
			for idx in main.player_info:
				print("player ", main.player_info[idx]["net_id"])
				# pass input to the correct player instance
				main.player_info[idx]["character_node"].process_client_input_message(message)
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
	var scene_manager: Node = get_node("/root/Main/SceneManager")
	var new_level: PackedScene = load(level_data["level_scene_path"])
	get_tree().get_root().get_node("Main/SceneManager").add_child(new_level.instance())
	# invoke the server's init_level callback sending the client ID back
	#rpc_id(1, "init_level_client_callback", get_tree().get_network_unique_id())
	init_level_client_callback_handler(get_tree().get_network_unique_id())
	
# Server calls this
func init_level_handler(id: int, level_data: Dictionary) -> void:
	print("telling the client ", id, " what level to init")
	rpc_id(id, "init_level", level_data)

func create_player(id: int) -> Character:
	var player_character_scene: PackedScene = load("res://Character/Character.tscn")
	var player_character: Character = player_character_scene.instance()
	if get_tree().is_network_server():
		# this ensures that this particular instance of a Character is only controlled via
		# the puppet_process_input function
		player_character.server_puppet = true
	else:
		player_character.local_player = true
	player_character.name = str(id)
	get_tree().get_root().get_node("Main/SceneManager").add_child(player_character)
	return player_character

remote func init_player():
	var sender: int = get_tree().get_rpc_sender_id()
	print("sender ", sender)
	if sender != 1:
		return
	print("initializing the player!")
	create_player(get_tree().get_network_unique_id()) # make a player on the client

func init_player_handler(id: int):
	rpc_id(id, "init_player")
