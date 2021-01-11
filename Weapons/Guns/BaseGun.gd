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

onready var animation_player = $AnimationPlayer
var shooting = false

func _ready() -> void:
	player = get_node(player_path)
	# ---
	# Scale the raycast Z value
	raycast = get_node(raycast_path)
	raycast.cast_to *= raycast_range

func _physics_process(delta: float) -> void:
	#process_input(delta)
	# compute accuracy
	var movement_penalty = 0.0
	if has_movement_penalty and player.vel.length() > 0:
		movement_penalty = min(base_accuracy - 0.1, base_movement_penalty + player.vel.length() / 100)
	accuracy = base_accuracy - movement_penalty
	if shooting:
		# trigger the recoil animation
		animation_player.play("BasicRecoil", -1, 2)
#		print("movement penalty: " + str(movement_penalty))
#		print("accuracy: " + str(accuracy))
		var first_hit = raycast.get_collider()
		var raycast_norm = raycast.get_collision_normal()
		var hit_position = raycast.get_collision_point()
		if first_hit:
#			print('Hitting: ', first_hit)
			if first_hit is RigidBody:
				first_hit.apply_impulse(hit_position, -raycast_norm * base_damage / 500) # small impulse?

func process_action(action_message: Dictionary) -> void:
	shooting = action_message.get("pressed", false)
