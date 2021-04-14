extends KinematicBody

class_name Character

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
var rotation_helper: Spatial
var MOUSE_SENSITIVITY = 0.05
var server_puppet: bool = false
var local_player: bool = false
var local_input_queue = []
onready var gun: Spatial = find_node("BaseGun")
onready var game_state_network_interface: Node = $"/root/Main/GameStateNetworkInterface"

var state: Dictionary

func _ready():
	# init the state dictionary
	state = {
		"id": int(self.name),
		"hp": HP,
		"ammo": 50,
		"origin": transform.origin,
		"basis": transform.basis
	}
	
	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper
	
	if !get_tree().is_network_server():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	#process_input(delta)
	if local_player:
		client_process_input(delta)
	process_movement(delta)

#func reconcile_with_server(new_state: Dictionary) -> void:
#	print("RECIEVING NEW_STATE: \n", new_state, "\n", "ID: ", self.name)
#	HP = new_state["hp"]
#	transform.origin = new_state["origin"]
#	transform.basis = new_state["basis"]
	
func update_state(new_state: Dictionary) -> void:
	#("RECIEVING NEW_STATE: \n", new_state, "\n", "ID: ", self.name)
	HP = new_state["hp"]
	transform.origin = new_state["origin"]
	transform.basis = new_state["basis"]

func process_client_input_message(input_message: Dictionary):
	# convert the dictionary into an InputEventAction object
	var event = InputEventAction.new()
	event.action = input_message.get("action")
	event.pressed = input_message.get("pressed")
	event.strength = input_message.get("strength")
	# pass into the character process_input function
	self.puppet_process_input(event)

func client_process_input(delta: float) -> void:
	# construct an input message from data that is polled from the Input Singleton
	var action_message_list: Array = []
	# TODO: should instead define and only use a set of actions that are meanigful to send to the server
	# rather than iteraing all the defined actions.
	for action in InputMap.get_actions():
		#if Input.is_action_pressed(action):
		var action_message: Dictionary = {
			"id": int(self.name),
			"message_type": "input_action",
			"action": action,
			"pressed": Input.is_action_pressed(action),
			"strength": Input.get_action_strength(action),
			"just_pressed": Input.is_action_just_pressed(action),
			"just_released": Input.is_action_just_released(action)
		}
		action_message_list.push_back(action_message)
	# -----
	# Process the action messages now
	# -----
	process_actions(action_message_list)
	# -----
	# Send the list of inputs from this frame to the server
	# -----
#	$"/root/Main/NetworkInterface".push_client_message_handler({
#		"id": int(self.name),
#		"message_type": "action_list",
#		"action_list": action_message_list
#	})
	game_state_network_interface.push_state_message({
		"id": int(self.name),
		"message_type": "action_list",
		"action_list": action_message_list
	})
	
	# capture / free cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func process_actions(action_message_list: Array) -> void:
	# ---
	# Walking
	dir = Vector3()
	var cam_xform = camera.get_global_transform()
	var input_movement_vector = Vector2()
	
	# I'm not sure this is much cleaner than just doing a set of if's...
	for action_message in action_message_list:
#		var action_message: Dictionary = action_message_list.pop_back()
		# Doing it this way generates pretty high network volume, but meh I don't care right now.
		match action_message:
			{"action":"ui_up", "pressed":true, ..}:
				input_movement_vector.y += 1
			{"action":"ui_down", "pressed":true, ..}:
				input_movement_vector.y -= 1
			{"action":"ui_left", "pressed":true, ..}:
				input_movement_vector.x -= 1
			{"action":"ui_right", "pressed":true, ..}:
				input_movement_vector.x += 1
			{"action":"fire", ..}:
				gun.process_action(action_message)
			{"action":"slow_walk", ..}:
				is_slow_walking = action_message.get("pressed", false)
			{"action":"jump", "just_pressed":true, ..}:
				if is_on_floor():
					vel.y = JUMP_SPEED
	
	input_movement_vector = input_movement_vector.normalized()
	
	# Basis vectors are already normalized
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x

func puppet_process_input(action_message_list: Array):
	#("processing action_message in puppet: ", action_message_list)
	process_actions(action_message_list)
			
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

func process_rotation(relative_x: float, relative_y: float) -> void:
	rotation_helper.rotate_x(deg2rad(relative_y * MOUSE_SENSITIVITY))
	self.rotate_y(deg2rad(relative_x * MOUSE_SENSITIVITY * -1))
	
	var camera_rot: Vector3 = rotation_helper.rotation_degrees
	camera_rot.x = clamp(camera_rot.x, -MAX_LOOK_ANGLE, MAX_LOOK_ANGLE)
	rotation_helper.rotation_degrees = camera_rot
	
func _input(event: InputEvent) -> void:
	if local_player and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var message: Dictionary = {
			"id": int(self.name),
			"message_type": "mouse_motion",
			"relative_x": event.relative.x,
			"relative_y": event.relative.y
		}
		# push the message to the server
#		$"/root/Main/NetworkInterface".push_client_message_handler(message)
		game_state_network_interface.push_state_message(message)
		# update rotation locally
		self.process_rotation(message["relative_x"], message["relative_y"])
