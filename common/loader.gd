extends Node

var config: Dictionary = {}
var godot_bin_path: String = "../../GodotBins/Godot_v3.2.4-beta4_x11.64"
func _ready() -> void:
	if "server" in OS.get_cmdline_args():
		# check for server_config.json and load it if present
		var config_file: File = File.new()
		var exists: bool = config_file.file_exists("./server_config.json")
		if exists:
			print("server config file found.")
		# command line args will supercede those defined by the config file
		for arg in OS.get_cmdline_args():
			if arg.find("=") > -1:
				var key_value: Array = arg.split("=")
				config[key_value[0].lstrip("--")] = key_value[1]
	else: # assume we are a client
		var config_file: File = File.new()
		var exists: bool = config_file.file_exists("./client_config.json")
		if exists:
			print("client config file found.")

	print(config)
	
	if OS.has_feature("standalone"):
		# Load resource pack data.pck
		ProjectSettings.load_resource_pack("data.pck", false)
	else:
		# We are running from the editor
		print("Hey I was launched from the editor!")
		# TODO implement some kind of hacky crap to do a hybrid client server setup
		# to make dev go a lot faster.
