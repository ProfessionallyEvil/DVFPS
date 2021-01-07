extends KinematicBody

export var HP = 100.0
export var GRAVITY = -24.8
var vel = Vector3()
export var MAX_SPEED = 20
export var JUMP_SPEED = 18
export var ACCEL = 4.5
export var MAX_LOOK_ANGLE = 70
export var AIR_CONTROL = true

var MAX_SLOW_WALK_SPEED = MAX_SPEED * 0.25
var SLOW_WALK_ACCEL = ACCEL
var is_slow_walking = false

var dir = Vector3()

const DEACCEL = 16
const MAX_SLOPE_ANGLE = 40

var camera
var rotation_helper

var MOUSE_SENSITIVITY = 0.05

func _ready():
	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _physics_process(delta):
	process_input(delta)
	process_movement(delta)

# hacky code to let the server dictate movement to the character
# TODO: refactor this to make input processing more decoupled from the input provider
func net_process_input(input_message: Dictionary, delta: float) -> void:
		
	# ---
	# Walking
	dir = Vector3()
	var cam_xform = camera.get_global_transform()
	
	var input_movement_vector = Vector2()
	
	if Input.is_action_pressed("ui_up"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("ui_down"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("ui_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_movement_vector.x += 1
	
	input_movement_vector = input_movement_vector.normalized()
	
	# Basis vectors are already normalized
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x
	
	# ---
	# slow walking
	if Input.is_action_pressed("slow_walk"):
		is_slow_walking = true
	else:
		is_slow_walking = false
	
	# ---
	# jumping
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vel.y = JUMP_SPEED
	
	# capture / free cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func process_input(delta):
	if !get_tree().is_network_server():
		rpc_id(1, "hello")
#		rpc_id(1, "enqueue_input_method", {
#			"token": "foo",
#			"net_id": get_tree().get_network_unique_id(),
#			"input_data": {}
#		})
	# ---
	# Walking
	dir = Vector3()
	var cam_xform = camera.get_global_transform()
	
	var input_movement_vector = Vector2()
	
	if Input.is_action_pressed("ui_up"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("ui_down"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("ui_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_movement_vector.x += 1
	
	input_movement_vector = input_movement_vector.normalized()
	
	# Basis vectors are already normalized
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x
	
	# ---
	# slow walking
	if Input.is_action_pressed("slow_walk"):
		is_slow_walking = true
	else:
		is_slow_walking = false
	
	# ---
	# jumping
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vel.y = JUMP_SPEED
	
	# capture / free cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()
	
	vel.y += delta * GRAVITY
	
	var hvel = vel
	hvel.y = 0
	
	var target = dir
	if is_slow_walking:
		target *= MAX_SLOW_WALK_SPEED
	else:
		target *= MAX_SPEED
	
	var accel
	if dir.dot(hvel) > 0:
		if is_slow_walking:
			accel = SLOW_WALK_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL
		
	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
	
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -MAX_LOOK_ANGLE, MAX_LOOK_ANGLE)
		rotation_helper.rotation_degrees = camera_rot
		
# -----
# RPC
# -----
remote func hello():
	print("This was called by client ", get_tree().get_rpc_sender_id())
