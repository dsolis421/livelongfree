extends CharacterBody2D

class_name Player
signal player_died

@export var projectile_scene: PackedScene
@onready var gun_timer = $GunTimer
@export var game_over_screen: PackedScene
@export var explosion_scene: PackedScene

# --- SPELL CONFIGURATION ---
@export_group("Spell Stats")
@export var invincible_duration: float = 5.0
@export var nuke_damage: int = 9999
@export var meteor_damage: int = 100 # Increased from 50
@export var meteor_impact_radius: float = 150.0 # How big is the explosion?

# --- CONFIGURATION ---
@export var movement_speed: float = 300.0

var damage_multiplier: float = 1.0
var cooldown_modifier: float = 1.0 # Lower is faster
var is_invincible: bool = false

const BASE_COOLDOWN_TIME: float = 0.5 # The starting speed
const MIN_COOLDOWN_MODIFIER: float = 0.2 # Cap: Don't fire faster than 0.1s (0.5 * 0.2)
const MAX_SPEED: float = 500.0 # Cap: Don't go faster than this
# --- CONNECTIONS ---
# We export this variable so we can drag the Joystick node into it later.
@export var joystick: VirtualJoystick 

func _physics_process(_delta: float) -> void:
	move()

func move() -> void:
	var direction: Vector2 = Vector2.ZERO
	
	# 1. Check Joystick Input
	if joystick:
		direction = joystick.get_output()

	# 2. Check Keyboard Input (For testing on PC without joystick)
	# If joystick is not moving (zero), we check WASD/Arrow keys
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 3. Apply Velocity
	if direction.length() > 0:
		velocity = direction * movement_speed
	else:
		# Slow down instantly if no input
		velocity = Vector2.ZERO

	# 4. Godot Physics Move
	move_and_slide()
	
func die() -> void:
	player_died.emit()
	print("Player has died!")
	# 1. Instantiate the Game Over UI
	if game_over_screen:
		var screen = game_over_screen.instantiate()
		get_tree().root.add_child(screen)

	# 2. Pause the game so everything stops moving
	get_tree().paused = true

	# 3. Optional: Delete the player or hide them
	queue_free()

# This function is called by Enemies when they touch you.
# We accept an 'amount' argument to be future-proof, even if we don't use it yet.
func take_damage(amount: int = 1) -> void:
	# 1. THE CHECK: Are we invincible?
	if is_invincible:
		print("Damage Blocked! (Invincible)")
		return # Do nothing!

	# 2. If not invincible, we die (since we have 1 HP)
	die()
	
func get_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return null
	
	var nearest_enemy = null
	var min_dist = INF # Start with "Infinite" distance
	
	for enemy in enemies:
		# Calculate distance to this specific goblin
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_enemy = enemy
			
	return nearest_enemy
	
func _on_gun_timer_timeout() -> void:

	# 1. Use the helper function to find a target
	var target = get_nearest_enemy()

	# 2. If no enemies exist, stop here (don't shoot at nothing)
	if target == null:
		return 
	# 3. Create a copy of the bullet blueprint
	var bullet = projectile_scene.instantiate()
	
	# We do this so the bullet moves independently of the player
	get_parent().add_child(bullet)
	bullet.damage = 1 * damage_multiplier # Assuming 1 is base damage
	# 4. Set the bullet's starting position to the Player's position
	bullet.global_position = global_position

	# 5. Calculate the direction: (Destination - Start)
	var direction = (target.global_position - global_position).normalized()
	bullet.direction = direction
	
	# 6. Rotate the bullet sprite to face the target (optional visual polish)
	bullet.rotation = direction.angle()
	
	# 7. Add the bullet to the "Main" scene (get_parent() is usually Main)
	
func apply_upgrade(type: String) -> void:
	match type:
		"movement_speed":
			if movement_speed >= MAX_SPEED:
				print("Speed Maxed Out!")
				return
			movement_speed += 20.0
			print("Speed Upgraded! New Speed: ", movement_speed)
		"cooldown":
			# check if we are already at max fire rate
			if cooldown_modifier <= MIN_COOLDOWN_MODIFIER:
				print("Fire Rate Maxed Out!")
				return
			cooldown_modifier -= 0.03
			if cooldown_modifier < MIN_COOLDOWN_MODIFIER:
				cooldown_modifier = MIN_COOLDOWN_MODIFIER
			# Apply to Timer
			$GunTimer.wait_time = BASE_COOLDOWN_TIME * cooldown_modifier
			print("Fire Rate Upgraded! New Wait Time: ", $GunTimer.wait_time)
			
		# "damage": REMOVED. Logic deleted to prevent confusion.

func _on_player_died() -> void:
	pass # Replace with function body.

func activate_power_weapon(type: String) -> void:
	match type:
		"invincible":
			cast_invincible()
		"nuke":
			cast_nuke()
		"meteor":
			cast_meteor()

# --- SPELL 1: INVINCIBILITY (Gold) ---
func cast_invincible() -> void:
	if is_invincible:
		return # Don't stack it if already active
	print("PLAYER IS GODLIKE!")
	is_invincible = true
	
	# Visual Feedback: Turn Gold
	var original_modulate = self.modulate
	self.modulate = Color(2, 2, 0, 1) # Bright Gold (Values > 1 make it glow!)
	
	# Wait for 5 seconds
	await get_tree().create_timer(invincible_duration).timeout
	
	# Revert
	is_invincible = false
	self.modulate = original_modulate
	print("Player is mortal again.")

# --- SPELL 2: NUKE (Green) ---
func cast_nuke() -> void:
	print("NUKE TRIGGERED!")
	# Get all enemies currently in the game
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	# Loop through them and destroy them
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			# Deal massive damage (so they run their death logic/animations)
			enemy.take_damage(nuke_damage) 
			
			# Optional: Add a screen shake here later!

# --- SPELL 3: METEOR (Red) ---
func cast_meteor() -> void:
	print("METEOR CAST!")
	
	if not explosion_scene:
		print("Error: No Explosion Scene assigned!")
		return

	var all_enemies = get_tree().get_nodes_in_group("enemy")
	if all_enemies.is_empty():
		return
		
	# 1. FILTER: Find enemies on screen
	var visible_enemies = []
	var screen_size = get_viewport_rect().size
	var player_pos = global_position
	
	# Box check: roughly half screen width + buffer
	var max_dx = (screen_size.x / 2) + 100 
	var max_dy = (screen_size.y / 2) + 100
	
	for enemy in all_enemies:
		var dx = abs(enemy.global_position.x - player_pos.x)
		var dy = abs(enemy.global_position.y - player_pos.y)
		
		if dx < max_dx and dy < max_dy:
			visible_enemies.append(enemy)
	
	# 2. SELECT TARGET
	var target = null
	
	if visible_enemies.size() > 0:
		target = visible_enemies.pick_random()
	else:
		# Fallback: Find closest off-screen enemy
		target = all_enemies[0]
		var closest_dist = 99999.0
		for enemy in all_enemies:
			var d = player_pos.distance_to(enemy.global_position)
			if d < closest_dist:
				closest_dist = d
				target = enemy

	# 3. SPAWN (The Fix: Add to scene BEFORE setting position)
	var boom = explosion_scene.instantiate()
	get_tree().current_scene.add_child(boom) 
	
	# Now force the position
	boom.global_position = target.global_position
