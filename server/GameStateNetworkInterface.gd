extends Node

var main: Node

func _ready() -> void:
	main = $"/root/Main"

# -----
# This defines all of the RPC calls that clients can use to communicate with the 
# server when it comes to sending state related information such as input messages
# -----

###########################
# Communicate to a client #
###########################

func update_game_state(client_id: int, new_state: Dictionary) -> void:
	#("RECONCILING STATE WITH CLIENT: ", client_id)
	rpc_id(client_id, "update_game_state", new_state)

# -----
# Clients call this RPC funciton to pass the server new input information which
# the server in turn uses to update it's simulation of the game thus updating the
# game state.
# -----
remote func handle_state_message(message: Dictionary) -> void:
	var message_type: String = message.get("message_type", null)
	var main: Node = $"/root/Main"
	#var sender_id: int = get_tree().get_rpc_sender_id()
	var sender_id: int = int(message["id"]) # ;^)
	if sender_id == int(message["id"]):
		match message_type:
			"action_list":
				# get_node("/root/Main/InputQueue").push_message(message)
				# more spaghetti code
				#("player input_action_list ", main.player_info[sender_id]["client_id"], " ", message)
				# pass input to the correct player instance
				main.player_info[sender_id]["character_node"].puppet_process_input(message["action_list"])
			"mouse_motion":
				#("player mouse_motion", main.player_info[sender_id]["client_id"], " ", message)
				main.player_info[sender_id]["character_node"].process_rotation(
					message["relative_x"],
					message["relative_y"]
				)
			"health_update":
				main.player_info[sender_id]["character_node"].puppet_process_input()
			_: return
