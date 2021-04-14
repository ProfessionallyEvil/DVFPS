extends Node

func _ready() -> void:
	var path: String = "res://client/main.tscn"
	# parse args
	var args = {}
	for arg in OS.get_cmdline_args():
		if arg.find('=') > -1:
			var key_value = arg.split('=')
			args[key_value[0].lstrip('--')] = key_value[1]

	if ("--server" in OS.get_cmdline_args() or Loader.config.get("editor_server", false)):
		path = "res://server/main.tscn"

	if ("server_ip" in args):
		Loader.config["server_ip"] = args["server_ip"]
	
	if ("server_port" in args):
		Loader.config["server_port"] = args["server_port"]
	
	print(Loader.config)
	# transition to correct scene
	get_tree().change_scene(path)
