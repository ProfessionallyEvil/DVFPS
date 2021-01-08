extends Node

var level_data: Dictionary = {}
var player_info: Dictionary = {}
var input_message_queue = []

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
	
func _player_connected(id: int) -> void:
	print("player connected: ", id)
	# register the player id in the list of player
	# TODO fetch player profile information from the auth api
	player_info[id] = { "net_id": id } # bogus test setup for now
	# set the level here on the server too
	var level: PackedScene = load(level_data["level_scene_path"])
	get_node("SceneManager").add_child(level.instance())
	# make the player init a level too
	network_interface.init_level_handler(id, level_data)

func _player_disconnected(id: int) -> void:
	print("player disconnected: ", id)

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
	print(input_message)
	var authenticated: bool
	var token: String = input_message.get("token")
	
	# TODO validate the message structure
	
	if !token:
		return
	authenticated = authenticate(token)
	if authenticated:
		# enqueue the message
		input_message_queue.append(input_message)
