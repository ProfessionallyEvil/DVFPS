extends Spatial


# length of the X component of the raycast direction in "units"
export var raycast_range = 50.0
export var base_damage = 75.0
export var headshot_damage_multiplier = 1.5
export var has_damage_falloff = false
export var damage_falloff_multiplier = 0.02 # reduce the damage by 2% for every "unit" that the "projectile" travels
export var base_accuracy = 0.9
export var base_movement_penalty = 0.2
export var has_movement_penalty = true
export var fire_rate = 0.21 # measured in seconds between rounds TODO: revisit this
export var recoil = 0.2 # take -recoil to accuracy when shooting
export var player_path: NodePath
var player: Node
# computed each frame
var accuracy: float
# expects there to a be a raycast node attached to the fire point in the scene
export var raycast_path: NodePath
var raycast: RayCast

var shooting = false

func _ready() -> void:
	player = get_node(player_path)
	# ---
	# Scale the raycast Z value
	raycast = get_node(raycast_path)
	raycast.cast_to.z *= raycast_range

func _physics_process(delta: float) -> void:
	process_input(delta)
	if shooting:
		# compute accuracy
		var movement_penalty = 0.0
		if has_movement_penalty and player.vel.length() > 0:
			movement_penalty = min(base_accuracy - 0.1, base_movement_penalty + player.vel.length() / 100)
		accuracy = base_accuracy - movement_penalty
		print("movement penalty: " + str(movement_penalty))
		print("accuracy: " + str(accuracy))
		# accuracy can be factored into computing the spread of each shot
		# ---
		# compute spread (ideally we would have spread patterns but random is easier)
		# ---
		# fire
		# 	can we fire this frame? 
		# 	Did we hit anything this frame
		#	etc
		var first_hit = raycast.get_collider()
		print('Hitting: ', first_hit)

func process_input(delta: float) -> void:
	if Input.is_action_pressed("fire"):
		shooting = true
	else:
		shooting = false
