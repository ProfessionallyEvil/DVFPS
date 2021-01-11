extends Node

var main: Node

func _ready() -> void:
	main = $"/root/Main"

##############################
# Communitcate to the server #
##############################

# -----
# This interface defines funcitons which clients will use to invoke RPC calls implemented 
# by the server
# -----

func push_state_message(message: Dictionary) -> void:
	rpc_id(1, "handle_state_message", message)

#########################################
# Receive communication from the server #
#########################################

# -----
# The server invokes this over RPC to push a list of player state updates to the
# client. This includes new states for the player and for the puppets of the other 
# players.
# -----
remote func update_game_state(new_state: Dictionary) -> void:
	#print(get_tree().get_network_unique_id(), " updating state ", new_state)
	var caller_id: int = get_tree().get_rpc_sender_id()
	if caller_id != 1:
		return
	
	# -----
	# TODO: update match state, scores, etc
	# -----
	
	# -----
	# Updated the player states
	# -----
	# get the player to update with the server response
#	var main: Node = $"/root/Main"
#	for id in new_state["player_states"]:
#		var character_ref: Character = main.player_info.get(id, null)
#		if character_ref:
#			character_ref.reconcile_with_server(new_state["player_states"][id])
	for id in new_state["player_states"]:
		var player_info: Dictionary = main.player_info.get(id, {})
		var character_ref: Character
		if player_info:
			character_ref = player_info.get("character_node")
		if character_ref:
			character_ref.update_state(new_state["player_states"][id])
