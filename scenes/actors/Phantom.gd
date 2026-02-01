extends "res://scenes/actors/Enemy.gd" # Explicitly inherit the base enemy

var is_approaching: bool = true
var wander_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Note: We do NOT start the vanish timer yet. 
	# We wait until it actually arrives so it doesn't despawn while traveling.
	pass
	
func _physics_process(delta: float) -> void:
	if player == null:
		return
		
	if is_approaching:
		# PHASE 1: FLY TOWARDS PLAYER
		var dist = global_position.distance_to(player.global_position)
		
		# Move straight to player
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * movement_speed
		move_and_slide()
		
		# Check if we arrived (500px range)
		if dist < 500.0:
			start_wandering()
			
	else:
		# PHASE 2: GHOST WANDER (Existing Logic)
		velocity = wander_direction * movement_speed
		move_and_slide()
		
		# Drift logic
		var drift = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 0.05
		wander_direction = (wander_direction + drift).normalized()

func start_wandering() -> void:
	is_approaching = false
	print("Phantom arrived! Starting timer.")
	
	# Pick random initial direction
	change_direction()
	
	# NOW we start the countdown (10 seconds from arrival)
	var timer = get_tree().create_timer(10.0)
	timer.timeout.connect(_on_vanish_timer)
	
func change_direction() -> void:
	# Pick a random angle
	var angle = randf() * TAU
	wander_direction = Vector2(cos(angle), sin(angle))

func _on_vanish_timer() -> void:
	# Optional: Play a sound or fade out tween here.
	print("Phantom escaped!")
	queue_free()
