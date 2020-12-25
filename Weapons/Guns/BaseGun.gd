extends Spatial


# length of the X component of the raycast direction in "units"
export var raycast_range = 50.0
export var base_damage = 75.0
export var headshot_damage_multiplier = 1.5
export var has_damage_falloff = false
export var damage_falloff_multiplier = 0.02 # reduce the damage by 2% for every "unit" that the "projectile" travels

# expects there to a be a raycast node attached to the fire point in the scene
export var raycast_path: NodePath
var raycast: RayCast

func _ready() -> void:
	# ---
	# Scale the raycast Z value
	raycast = get_node(raycast_path)
	raycast.cast_to.z *= raycast_range

func _process(delta: float) -> void:
	print("hey")
	print(raycast.cast_to.z)
