extends CanvasLayer
	
var hud_center_container

func _ready():
	get_tree().root.connect("size_changed", self, "_on_viewport_size_changed")
	hud_center_container = $HUD_CenterContainer
	hud_center_container.margin_right = OS.window_size.x
	hud_center_container.margin_bottom = OS.window_size.y

func _on_viewport_size_changed():
	hud_center_container.margin_right = OS.window_size.x
	hud_center_container.margin_bottom = OS.window_size.y
