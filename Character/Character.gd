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

var is_server_character = false
var is_player = true

func _ready():
	is_server_character = get_tree().is_network_server()

	if is_server_character:
		# connect to the InputQueue - we should ideally check to make sure it exists and error handle, but meh
		$"/root/Main/InputQueue".connect("message_pushed", self, "_on_InputQueue_message_pushed")

	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_InputQueue_message_pushed(id: int) -> void:
	# check if the message belongs to this instance of the player using the network id
	print("Got a message from ", id)
	var message = $"/root/Main/InputQueue".pop_message()
	print(message)

func _physics_process(delta):
	#process_input(delta)
	process_movement(delta)

func process_input(event: InputEvent):
	if is_server_character:
		pass
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
	
func _input(event: InputEvent) -> void:
	# This is terribly spaghetti. You're better than this, Cory >:(
	if is_player and event.is_action_type():
		print("sending input action to server")
		# send the input to the server
		# and also go ahead and process the input locally
		for action in InputMap.get_actions():
			if InputMap.event_is_action(event, action):
				var message = {
					"id": self.name, # possibly not the best way to track who this message belongs to
					"message_type": "input_action",
					"action": action,
					"strength": Input.get_action_strength(action),
					"pressed": Input.is_action_pressed(action)
				}
				print(message)
				$"/root/Main/NetworkInterface".push_client_message_handler(message)
				process_input(event)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -MAX_LOOK_ANGLE, MAX_LOOK_ANGLE)
		rotation_helper.rotation_degrees = camera_rot
