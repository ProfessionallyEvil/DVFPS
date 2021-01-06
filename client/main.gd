extends Node

var player_info: Dictionary = {}

func _ready():
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connection_failed")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	var server_ip: String = Loader.config.get("server_ip", "127.0.0.1")
	var port: int = int(Loader.config.get("port", 9999))
	print("Connecting to server at ", server_ip, ":", port)
	# --------------------------------------------------------------------------
	# Create the network API object and listen for connections
	# TODO: Extract all server management stuff out in to a library that handles all of 
	# this, allowing us to swap in a GDNative version down the line without too much trouble.
	# This would also allow me to extract it into common and use it on the client and the server
	var net = NetworkedMultiplayerENet.new()
	net.create_client(server_ip, port)
	get_tree().set_network_peer(net)
	print("Hello from the client!")
	
func _connected_ok() -> void:
	print("Connected to server")

func _connection_failed() -> void:
	print("Connection failed")

func _server_disconnected() -> void:
	print("Disconnected from server")
	
remote func hello(message: String) -> void:
	# check the id of the sender
	var id = get_tree().get_rpc_sender_id()
	# TODO work out how to establish cryptographic authenticity of the server pinging back at us
	# Likely baked in as part of the DTLS implementation in NetworkedMultiplayerENet
	print(id, " says ", message)

remote func init_game(init_data: Dictionary) -> void:
	var id = get_tree().get_rpc_sender_id()
	print(init_data)
	if id != 1:
		return
	get_tree().change_scene(init_data["level_scene_path"])
