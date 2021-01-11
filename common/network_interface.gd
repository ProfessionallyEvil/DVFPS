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
	var character_ref: Character = create_player(id, true) # make a player on the server
	# stuff a reference to the player in the correct entry in player_info
	var main: Node = $"/root/Main"
	if main.player_info.get(id, null):
		main.player_info[id]["character_node"] = character_ref
	# create the player back on the client
	self.init_player_handler(id)
	# initialize a puppet of this player on the other clients
	for idx in main.player_info:
		var player: Dictionary = main.player_info[idx]
		for idy in main.player_info: 
			if idx != idy:
				self.init_puppet(idy, idx)

# This will get invoked by nodes in the client to allow for the node paths to match up
func init_level_client_callback_handler(id: int) -> void:
	# invoke the "init_level_client_callback" RPC on the server from the client
	rpc_id(1, "init_level_client_callback", id)

remote func process_client_message(message: Dictionary) -> void:
	var message_type: String = message.get("message_type", null)
	# print(message)
	var main: Node = $"/root/Main"
	var sender_id: int = get_tree().get_rpc_sender_id()
	if sender_id == int(message["id"]):
		match message_type:
			"action_list":
				# get_node("/root/Main/InputQueue").push_message(message)
				# more spaghetti code
				print("player input_action_list ", main.player_info[sender_id]["net_id"], " ", message)
				# pass input to the correct player instance
				main.player_info[sender_id]["character_node"].puppet_process_input(message["action_list"])
			"mouse_motion":
				print("player mouse_motion", main.player_info[sender_id]["net_id"], " ", message)
				main.player_info[sender_id]["character_node"].process_rotation(
					message["relative_x"],
					message["relative_y"]
				)
			_: return

func push_client_message_handler(message: Dictionary) -> void:
	rpc_id(1, "process_client_message", message)

# -----
# Client RPC Functions - these will execute on the client
# These should only be called by the server, a naive protection is to check if
# the rpc_caller_id is 1, but in theory this can be spoofed without encrypiton!
# -----
remote func init_level(level_data) -> void:
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
	init_level_client_callback_handler(get_tree().get_network_unique_id())
	
# Server calls this
func init_level_handler(id: int, level_data: Dictionary) -> void:
	rpc_id(id, "init_level", level_data)

remote func reconcile_with_server_rpc(new_state: Dictionary) -> void:
	#print(get_tree().get_network_unique_id(), " updating state ", new_state)
	var caller_id: int = get_tree().get_rpc_sender_id()
	print("CALLER ID: ", caller_id)
	if caller_id != 1:
		return
	# get the player to update with the server response
	var main: Node = $"/root/Main"
	for id in new_state["player_states"]:
		var character_ref: Character = main.player_info.get(id, null)
		if character_ref:
			character_ref.reconcile_with_server(new_state["player_states"][id])

func reconcile_with_client(id: int, new_state: Dictionary) -> void:
	print("RECONCILING STATE WITH CLIENT: ", id)
	rpc_id(id, "reconcile_with_server_rpc", new_state)

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

remote func init_player():
	var sender: int = get_tree().get_rpc_sender_id()
	if sender != 1:
		return
	print("initializing the player!")
	var character_ref: Character = create_player(get_tree().get_network_unique_id(), false) # make a player on the client
	var main: Node = $"/root/Main"
	main.player_info[get_tree().get_network_unique_id()] = character_ref

func init_player_handler(id: int):
	rpc_id(id, "init_player")

remote func init_puppet_rpc(puppet_id: int):
	var character_ref: Character = create_player(puppet_id, true)
	# add the character ref into the local collection of player information
	var main: Node = $"/root/Main"
	main.player_info[puppet_id] = character_ref
	print("ALL PLAYER INFO ", main.player_info)

func init_puppet(client_id: int, puppet_id: int):
	rpc_id(client_id, "init_puppet_rpc", puppet_id)
