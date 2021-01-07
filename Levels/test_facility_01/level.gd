extends Spatial

remote func init_player():
	print("initializing the player!")
	if get_tree().get_rpc_sender_id() != 1:
		return
	var player_character = load("res://Character/Character.tscn")
	player_character = str(player_character.instance())
	player_character.name = get_tree().get_network_unique_id()
	add_child(player_character)
