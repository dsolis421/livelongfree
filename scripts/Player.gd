extends CharacterBody2D
class_name Player
@export var projectile_scene: PackedScene
@onready var gun_timer = $GunTimer

@export var game_over_screen: PackedScene

# --- CONFIGURATION ---
@export var movement_speed: float = 300.0

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
	print("Player has died!")
	# 1. Instantiate the Game Over UI
	if game_over_screen:
		var screen = game_over_screen.instantiate()
		get_tree().root.add_child(screen)

	# 2. Pause the game so everything stops moving
	get_tree().paused = true

	# 3. Optional: Delete the player or hide them
	queue_free()

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
	print("Timer Fired!") # CHECK 1: Is the clock running?
	# 1. Use the helper function to find a target
	var target = get_nearest_enemy()
	print("Target found: ", target) # CHECK 2: Did we see a goblin?
	# 2. If no enemies exist, stop here (don't shoot at nothing)
	if target == null:
		return 
		
	# 3. Create a copy of the bullet blueprint
	var bullet = projectile_scene.instantiate()
	
	# We do this so the bullet moves independently of the player
	get_parent().add_child(bullet)
	
	# 4. Set the bullet's starting position to the Player's position
	bullet.global_position = global_position
	# DEBUG: Tell me where we are
	print("Player Pos: ", global_position)
	print("Bullet Spawn: ", bullet.global_position)
	# 5. Calculate the direction: (Destination - Start)
	var direction = (target.global_position - global_position).normalized()
	bullet.direction = direction
	
	# 6. Rotate the bullet sprite to face the target (optional visual polish)
	bullet.rotation = direction.angle()
	
	# 7. Add the bullet to the "Main" scene (get_parent() is usually Main)
	
