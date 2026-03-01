extends Node2D

# --- SCENE ASSIGNMENTS ---
@export var goblin_scene: PackedScene
@export var sprinter_scene: PackedScene
@export var brute_scene: PackedScene
@export var phantom_scene: PackedScene
@export var boss_scene: PackedScene 

func _ready() -> void:
	GameManager.level_up_triggered.connect(_on_level_up)
	GameManager.boss_spawn_requested.connect(spawn_boss)
	print("TIMER WAIT TIME IS CURRENLTY = ", $Timer.wait_time)
	print("GAMEMANAGER MOD IS CURRENLTY = ", GameManager.run_spawn_timer_mod)
	# --- NEW: APPLY SPAWN RATE SCALING ---
	# We grab the default time set in the Inspector (likely 1.0s)
	# And subtract the modifier (e.g., 0.1s per Damage Level)
	var new_wait_time = $Timer.wait_time - GameManager.run_spawn_timer_mod
	
	# Safety Clamp: Don't let it go below 0.1s or the game might crash
	if new_wait_time < 0.2:
		new_wait_time = 0.2
		
	$Timer.wait_time = new_wait_time
	print("Spawner: Spawn Rate adjusted to ", new_wait_time, "s")
	
func _on_level_up(_level: int) -> void:
	# Reset rhythm on level up
	$Timer.stop()
	$Timer.start()

func _on_timer_timeout() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null: return

	# Throttle fodder spawns during boss fight
	if GameManager.is_boss_active:
		if randf() < 0.75:
			return 

	var enemy_choice = pick_enemy_by_level()
	if enemy_choice == null: return

	# 1. Get Safe Position (Radius 25.0 for normal enemies)
	# Increase this to 35.0 or 40.0 if enemies are still clipping walls!
	var spawn_pos = get_valid_spawn_position(player, 100.0)
	
	# If failed (Vector2.ZERO), skip this spawn cycle entirely
	if spawn_pos == Vector2.ZERO:
		return 

	# 2. Instantiate
	var enemy = enemy_choice.instantiate()

	enemy.global_position = spawn_pos
	get_tree().current_scene.add_child(enemy)

func spawn_boss() -> void:
	if boss_scene == null:
		print("ERROR: No Boss Scene assigned!")
		return
	
	var boss = boss_scene.instantiate()
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		# BUG FIX 1: Request a MUCH larger radius for the Boss (e.g. 90.0)
		var safe_pos = get_valid_spawn_position(player, 90.0)
		
		# BUG FIX 2: Handle the failure case
		if safe_pos == Vector2.ZERO:
			# Fallback: Spawn 600px to the right of player if logic fails
			# (Better than spawning at 0,0 inside a rock)
			safe_pos = player.global_position + Vector2(600, 0)
			
		boss.global_position = safe_pos
	
	get_tree().current_scene.call_deferred("add_child", boss)
	GameManager.boss_has_spawned = true

func pick_enemy_by_level() -> PackedScene:
	var current_level = GameManager.level
	var roll = randf() 
	
	if current_level >= 6:
		if roll < 0.05: return phantom_scene 
		elif roll < 0.15: return brute_scene 
		elif roll < 0.45: return sprinter_scene
		else: return goblin_scene
	elif current_level >= 3:
		if roll < 0.2: return sprinter_scene
		else: return goblin_scene
	else:
		return goblin_scene

func get_valid_spawn_position(player: Node2D, required_radius: float = 30.0) -> Vector2:
	var camera = get_viewport().get_camera_2d()
	var zoom = camera.zoom if camera else Vector2.ONE
	var view_size = get_viewport_rect().size / zoom
	
	var buffer = 700 
	var half_w = (view_size.x / 2) + buffer
	var half_h = (view_size.y / 2) + buffer

	# Find the World Generator (So we can ask the Oracle)
	var world_gen = get_tree().get_first_node_in_group("world_generator")

	for i in range(15):
		var side = randi() % 4
		var spawn_offset = Vector2.ZERO

		match side:
			0: spawn_offset = Vector2(randf_range(-half_w, half_w), -half_h)
			1: spawn_offset = Vector2(randf_range(-half_w, half_w), half_h)
			2: spawn_offset = Vector2(-half_w, randf_range(-half_h, half_h))
			3: spawn_offset = Vector2(half_w, randf_range(-half_h, half_h))
		
		var candidate_pos = player.global_position + spawn_offset

		# --- CHECK 1: THE ORACLE (Noise Check) ---
		# This solves the "Spawn in Void" bug.
		if world_gen:
			# If the math says "This is a wall", skip immediately.
			# We check the center point. 
			if world_gen.is_position_wall(candidate_pos):
				continue # Try next loop
				
			# OPTIONAL: Check the 4 corners of the enemy radius too
			# to be extra safe for big Bosses.
			if world_gen.is_position_wall(candidate_pos + Vector2(required_radius, 0)) or \
			   world_gen.is_position_wall(candidate_pos - Vector2(required_radius, 0)) or \
			   world_gen.is_position_wall(candidate_pos + Vector2(0, required_radius)) or \
			   world_gen.is_position_wall(candidate_pos - Vector2(0, required_radius)):
				continue

		# --- CHECK 2: THE PHYSICS (Dynamic Obstacles) ---
		# We still keep this! It handles things that aren't terrain 
		# (like other enemies, crates, or if the chunk WAS already loaded).
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var shape = CircleShape2D.new()
		shape.radius = required_radius
		query.shape = shape
		query.transform = Transform2D(0, candidate_pos)
		query.collision_mask = 1 
		query.collide_with_bodies = true
		
		var result = space_state.intersect_shape(query)
		
		if result.is_empty():
			return candidate_pos
	
	return Vector2.ZERO
