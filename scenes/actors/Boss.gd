extends Enemy

class_name Boss

# --- THE BRAIN ---
enum State { CHASE, ORBIT, DASH, ATTACK }
var current_state: State = State.CHASE
# --- MOVEMENT SETTINGS ---
var dash_speed: float = 800.0   # Fast!
var orbit_distance: float = 250.0
var dash_direction: Vector2 = Vector2.ZERO
var is_dashing_active: bool = false # Acts as a safety lock during the "Wind Up"
# --- COMBAT SETTINGS ---
@export var boss_bullet_scene: PackedScene
var is_attacking: bool = false
# Make sure you added the Timer node to the scene and named it "BrainTimer"!
@onready var brain_timer = $BrainTimer

func _ready() -> void:
	# 1. Global Flags
	GameManager.is_boss_active = true
	print("--- BOSS FIGHT STARTED ---")
	
	# 2. Cleanup Groups (Safety measure)
	if is_in_group("fodder"): remove_from_group("fodder")
	if not is_in_group("elite"): add_to_group("elite")
	
	# 3. Connect the Brain
	if brain_timer:
		brain_timer.timeout.connect(_on_brain_decision)
		brain_timer.start()
	else:
		print("ERROR: BrainTimer node missing in Boss.tscn!")

func _physics_process(delta: float) -> void:
	# CRITICAL: We are OVERRIDING the Enemy.gd movement logic here.
	# We do NOT call super._physics_process(delta) because we want full control.
	
	match current_state:
		State.CHASE:
			state_chase(delta)
		State.ORBIT:
			state_orbit(delta)
		State.DASH:
			state_dash(delta)
		State.ATTACK:
			state_attack(delta)

	# Apply the velocity we calculated in the functions above
	move_and_slide()
	
	# Visual Rotation (Keep facing direction of travel)
	if velocity.length() > 0 and visual:
		visual.rotation = velocity.angle()

# --- STATE LOGIC HANDLERS ---

func state_chase(_delta: float) -> void:
	# Basic Zombie tracking (What you had before)
	if player:
		var direction = global_position.direction_to(player.global_position)
		# Uses 'movement_speed' from the parent Enemy class
		velocity = direction * movement_speed 

func state_orbit(_delta: float) -> void:
	if not player: return
	
	# 1. Get vector to player
	var to_player = global_position.direction_to(player.global_position)
	var distance = global_position.distance_to(player.global_position)
	
	# 2. Calculate Orbit Vector (Tangent)
	# Rotated 90 degrees (PI/2 radians)
	var orbit_dir = to_player.rotated(PI / 2)
	
	# 3. Calculate Correction Vector (Push/Pull)
	# If too far, move In (to_player). If too close, move Out (-to_player).
	var correction_dir = Vector2.ZERO
	if distance > orbit_distance + 20:
		correction_dir = to_player # Move Closer
	elif distance < orbit_distance - 20:
		correction_dir = -to_player # Move Away
		
	# 4. Combine them
	# We blend them: mostly orbit, a little bit of correction
	var final_dir = (orbit_dir + correction_dir * 0.5).normalized()
	
	velocity = final_dir * movement_speed

func state_dash(_delta: float) -> void:
	# Only move if the wind-up is finished
	if is_dashing_active:
		# Move in a STRAIGHT LINE based on where the player WAS 
		# (Do not update direction here, or he will home in like a missile)
		velocity = dash_direction * dash_speed
		
		# Friction? No. He's a bull. He goes full speed until the timer runs out.
	else:
		# Still winding up
		velocity = Vector2.ZERO

func state_attack(_delta: float) -> void:
	# Placeholder
	velocity = Vector2.ZERO

# --- THE DECISION MAKER ---

func _on_brain_decision() -> void:
	# Pick a random state
	var states = State.values()
	var new_state = states.pick_random()
	
	change_state(new_state)

func change_state(new_state: State) -> void:
	current_state = new_state
	print("Boss switched to state: ", State.keys()[new_state])
	# --- RESET FLAGS ---
	is_dashing_active = false
	is_attacking = false
	
	# --- STATE ENTRY LOGIC ---
	match current_state:
		State.DASH:
			prepare_dash()
		State.ATTACK:
			prepare_attack()
			
func prepare_dash() -> void:
	# 1. Stop Moving
	velocity = Vector2.ZERO
	
	# 2. Visual Tell (Tween)
	# We use a code-based animation to flash red and scale up
	if visual:
		var tween = create_tween()
		# Turn Red and Grow
		tween.tween_property(visual, "modulate", Color.RED, 0.5)
		tween.parallel().tween_property(visual, "scale", Vector2(1.2, 1.2), 0.5)
		# Wait a tiny bit
		tween.tween_interval(0.2)
		# Launch!
		tween.tween_callback(start_dash)

func start_dash() -> void:
	# 3. Lock Target
	if player:
		dash_direction = global_position.direction_to(player.global_position)
		is_dashing_active = true
		
		# Reset Visuals
		if visual:
			visual.modulate = Color.WHITE
			visual.scale = Vector2(1.0, 1.0) # Assume original scale is 1, adjust if you scaled in editor
		
func prepare_attack() -> void:
	# 1. Stop Moving
	velocity = Vector2.ZERO
	is_attacking = true
	# 2. Face the Player
	if player and visual:
		var to_player = global_position.direction_to(player.global_position)
		visual.rotation = to_player.angle()
	# 3. Wind Up (Flash Yellow/Orange)
	if visual:
		var tween = create_tween()
		tween.tween_property(visual, "modulate", Color.ORANGE, 0.4)
		tween.tween_callback(fire_shotgun)
		tween.tween_property(visual, "modulate", Color.WHITE, 0.2)
		
func fire_shotgun() -> void:
	if not is_attacking or not player or not boss_bullet_scene: return
	print(">>> BOSS FIRES SHOTGUN <<<")
	# Calculate direction to player
	var main_dir = global_position.direction_to(player.global_position)
	# Fire 5 bullets in a spread (-30 to +30 degrees)
	var angle_step = deg_to_rad(15)
	var start_angle = -2 * angle_step
	
	for i in range(5):
		var current_angle = start_angle + (i * angle_step)
		var bullet_dir = main_dir.rotated(current_angle)
		spawn_bullet(bullet_dir)

func spawn_bullet(dir: Vector2) -> void:
	var bullet = boss_bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.setup(dir)
	
func die() -> void:
	print("!!! BOSS DIE FUNCTION CALLED !!!")
	# 1. Notify the Manager to resume the game flow
	GameManager.on_boss_died()
	super.die()
