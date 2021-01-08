extends Node

func _ready() -> void:
	var path: String = "res://client/main.tscn"
	
	if ("--server" in OS.get_cmdline_args() or Loader.config.get("editor_server", false)):
		path = "res://server/main.tscn"
	# transition to correct scene
	get_tree().change_scene(path)
