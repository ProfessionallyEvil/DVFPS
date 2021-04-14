extends Node

var game_state: Dictionary = {}

var level_data: Dictionary = {}
var player_info: Dictionary = {}
var input_message_queue = []

var level_instantiated: bool = false

onready var game_state_network_interface: Node = $"/root/Main/GameStateNetworkInterface"
onready var network_interface: Node = get_node("NetworkInterface")

func _ready() -> void:
	var port: int = int(Loader.config.get("port", 9999))
	var max_players: int = int(Loader.config.get("max_players", 10))
	print(port, " ", max_players)
	# --------------------------------------------------------------------------
	# Create the network API object and listen for connections
	# TODO: Extract all server management stuff out in to a library that handles all of 
	# this, allowing us to swap in a GDNative version down the line without too much trouble.
	# This would also allow me to extract it into common and use it on the client and the server
	var net: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	var err: int = net.create_server(port, max_players)
	if err != OK:
		print("Failed to create server: ", err)
	get_tree().set_network_peer(net)
	
	# Connect network signals
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	
	# TODO pull this from config, and eventually allow users to create matches and specify the game modes and map
	level_data["level_scene_path"] = "res://Levels/test_facility_01/level.tscn"
	level_data["game_mode"] = "deathmatch"
	
	print("Hello from the server!")
	
func _player_connected(client_id: int) -> void:
#	print("player connected: ", id)
#	# register the player id in the list of player
#	# TODO fetch player profile information from the auth api
#	player_info[id] = { "net_id": id } # bogus test setup for now
#	# set the level here on the server too
#	if !level_instantiated:
#		var level: PackedScene = load(level_data["level_scene_path"])
#		get_node("SceneManager").add_child(level.instance())
#		level_instantiated = true
#	# make the player init a level too
#	network_interface.init_level_handler(id, level_data)
	var game_initialization_network_interface: Node = $"/root/Main/GameInitializationNetworkInterface"
	if !game_state.get("level_initialized", false):
		# init the server's version of the level
		game_initialization_network_interface.init_level(level_data)
		game_state["level_initialized"] = true
	game_initialization_network_interface.init_client_level(client_id, level_data)
	# make sure to instantiate the new server side character node as a server puppet (not to be confused with godot's concept of a puppet)
	var new_player: Character = game_initialization_network_interface.create_player(client_id, true)
	
	# Track the just created player node and the client id in the game player_info dictionary for easy retreival later
	player_info[client_id] = {
		"client_id": client_id,
		"character_node": new_player
	}
	
	# TODO: determine a spawn point for the player
	# Tell the just connected client to create a main player for itself
	game_initialization_network_interface.create_client_player(client_id, {
		"client_id": client_id,
		"spawn_point_node_path": "",
		"is_puppet": false
	})
	# update the puppets in all of the currently connected clients
	game_initialization_network_interface.broadcast_player_puppets()

func _player_disconnected(client_id: int) -> void:
	# TODO invalidate session and remove the player_info entry from the server
	# as well as remove it from all of the other clients
	print("player disconnected: ", client_id)

func _physics_process(delta: float) -> void:
	# TODO move to game node or GameStateNetworkInterface
	# toss out the updated player state data to each client
	var new_player_states: Dictionary = {}
	for pid in player_info:
		#("updating ", pid)
		var character_ref: Character = player_info[pid].get("character_node", null)
		#("CHARACTER REF: ", character_ref)
		if character_ref:
			new_player_states[pid] = {
				"id": player_info[pid]["client_id"],
				"hp": character_ref.HP,
				"origin": character_ref.transform.origin,
				"basis": character_ref.transform.basis
			}
			#("updated state ", new_player_states[pid])
	# send out the player states
	var new_game_state: Dictionary = {
		"match_status": "",
		"player_states": new_player_states
	}
	for client_id in player_info.keys():
		#("PUSHING NEW STATE TO: ", client_id)
		# network_interface.reconcile_with_client(client_id, new_game_state)
		game_state_network_interface.update_game_state(client_id, new_game_state)

# -----
# Helpers
# TODO: move to helper lib
# -----
func authenticate(token: String) -> bool:
	return true

# -----
# RPC
# -----
func hello():
	print("This was called by client ", get_tree().get_rpc_sender_id())
	
# A callback to allow the 
func level_initialized(id: int) -> void:
	if !(id in player_info.keys()):
		return
	# instance a player into the level
	var new_player = load("res://Character/Character.tscn")
	new_player = new_player.instance()
	player_info[id]["player_node"] = new_player
	new_player.name = str(id)
	# TODO determine level spawn point and send to client
	get_tree().get_root().add_child(new_player)
	# tell client level to instantiate a player
	# TODO: Generalize this to allow the server to tell the client where to instantiate
	# the player, supply the net id, spawn point, and whether or not it's another player
	rpc_id(id, "init_player")

func enqueue_input_message(input_message: Dictionary) -> void:
#	print(input_message)
	var authenticated: bool
	var token: String = input_message.get("token")
	
	# TODO validate the message structure
	
	if !token:
		return
	authenticated = authenticate(token)
	if authenticated:
		# enqueue the message
		input_message_queue.append(input_message)
