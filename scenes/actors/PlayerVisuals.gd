extends Node2D

# --- REFERENCES ---
@onready var body = $Body
@onready var hand_l = $Hand_L
@onready var hand_r = $Hand_R

# --- CONFIGURATION ---
var time: float = 0.0
var run_speed = 15.0 
var hover_speed = 4.0 
var arm_span = 10.0 
var rotation_speed = 10.0 # How fast we turn to face movement

# --- STATE ---
var base_body_pos: Vector2
var base_hand_l_pos: Vector2
var base_hand_r_pos: Vector2
var base_hand_l_rot: float
var base_hand_r_rot: float


func _ready() -> void:
	base_body_pos = body.position
	base_hand_l_pos = hand_l.position
	base_hand_r_pos = hand_r.position
	base_hand_l_rot = hand_l.rotation
	base_hand_r_rot = hand_r.rotation

func _process(delta: float) -> void:
	# 1. GET PLAYER DATA
	var player = get_parent()
	var velocity = player.velocity
	var is_moving = velocity.length() > 10.0
	
	# 2. FACE MOVEMENT DIRECTION (The Fix)
	if is_moving:
		# Calculate target angle based on movement
		var target_angle = velocity.angle()
		
		# Smoothly rotate towards that angle
		# 'lerp_angle' handles the wrap-around from 360 to 0 automatically
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)
	
	# 3. ANIMATE
	if is_moving:
		time += delta * run_speed
		animate_run(velocity)
	else:
		time += delta * hover_speed
		animate_idle()

func animate_run(_velocity: Vector2) -> void:
	# --- BODY BOB ---
	var bob = sin(time) * 2.0
	body.position.y = base_body_pos.y + bob
	
	# --- BODY LEAN ---
	# We rely on the main rotation for direction now.
	# We can add a tiny "acceleration tilt" if we want, but let's keep it simple first.
	body.rotation = lerp_angle(body.rotation, 0.0, 0.1) # Reset local tilt
	
	# --- ARM SWING ---
	var swing_amplitude = arm_span
	var swing = sin(time) * swing_amplitude
	var drag_tilt = cos(time) * -0.3
	# Hands swing relative to the rotation of the Visuals container
	hand_l.position.x = base_hand_l_pos.x + swing
	hand_l.position.y = base_hand_l_pos.y + (cos(time) * 2.0)
	hand_l.rotation = base_hand_l_rot + drag_tilt

	hand_r.position.x = base_hand_r_pos.x - swing
	hand_r.position.y = base_hand_r_pos.y + (cos(time + PI) * 2.0)
	hand_r.rotation = base_hand_r_rot - drag_tilt

func animate_idle() -> void:
	# Reset Body Lean
	body.rotation = lerp_angle(body.rotation, 0.0, 0.1)
	
	# Slow Hover
	var hover = sin(time) * 1.5
	body.position.y = base_body_pos.y + hover
	
	# Hands Return to Sides
	var target_l = base_hand_l_pos + Vector2(0, hover)
	var target_r = base_hand_r_pos + Vector2(0, hover)
	hand_l.position = hand_l.position.lerp(target_l, 0.1)
	hand_r.position = hand_r.position.lerp(target_r, 0.1)
	hand_l.rotation = lerp_angle(hand_l.rotation, base_hand_l_rot, 0.1)
	hand_r.rotation = lerp_angle(hand_r.rotation, base_hand_r_rot, 0.1)
