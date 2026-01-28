extends CharacterBody2D
class_name Player

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
