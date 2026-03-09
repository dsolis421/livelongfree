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
	
	var new_wait_time = $Timer.wait_time - GameManager.run_spawn_timer_mod
	if new_wait_time < 0.2:
		new_wait_time = 0.2
		
	$Timer.wait_time = new_wait_time
	print("Spawner: Spawn Rate adjusted to ", new_wait_time, "s")
	
func _on_level_up(_level: int) -> void:
	$Timer.stop()
	$Timer.start()

func _on_timer_timeout() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null: return

	if GameManager.is_boss_active:
		if randf() < 0.75:
			return 

	var enemy_choice = pick_enemy_by_level()
	if enemy_choice == null: return

	var world_gen = get_tree().get_first_node_in_group("world_generator")
	if not world_gen: return

	# 1. Ask the World Generator for a spawn location (600px to 1000px away)
	# This ensures they spawn just off-screen so the player doesn't see the wall pop.
	var spawn_data = world_gen.get_spawn_coordinates(player.global_position, 600.0, 1000.0)

	# 2. Instantiate the enemy
	var enemy = enemy_choice.instantiate()
	get_tree().current_scene.add_child(enemy)

	# 3. Handle the Phantoms (They ignore the wall mechanic entirely)
	if enemy_choice == phantom_scene:
		enemy.global_position = spawn_data["floor_pos"]
		# Phantoms don't need to peel, they just appear
		return

	# 4. THE BIOS PURGE MECHANIC
	if spawn_data["is_wall"]:
		# The enemy was given an infected wall! Trigger the peel animation.
		# We pass the wall position, the floor position, and a 1.2 second peel duration.
		enemy.start_wall_spawn(spawn_data["wall_pos"], spawn_data["floor_pos"], 1.2)
	else:
		# Fallback: The player is in a massive open area. 
		# Just spawn them normally on the floor.
		enemy.global_position = spawn_data["floor_pos"]

func spawn_boss() -> void:
	if boss_scene == null:
		print("ERROR: No Boss Scene assigned!")
		return
	
	var boss = boss_scene.instantiate()
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		# The Boss still uses its dedicated, guaranteed open-space finder.
		# Bosses do not peel out of walls!
		var safe_pos = get_guaranteed_boss_spawn(player, 90.0)
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

func get_guaranteed_boss_spawn(player: Node2D, required_radius: float = 90.0) -> Vector2:
	var world_gen = get_tree().get_first_node_in_group("world_generator")
	var space_state = get_world_2d().direct_space_state

	var current_radius = 800.0 # Start safely off-screen
	var max_radius = 3000.0    # Hard cap so the game doesn't freeze in an infinite loop

	while current_radius <= max_radius:
		# Calculate how many points to check on this ring (larger ring = more checks)
		var steps = max(8, int(current_radius / 50.0)) 
		
		for i in range(steps):
			var angle = (TAU / steps) * i
			var offset = Vector2(cos(angle), sin(angle)) * current_radius
			var candidate_pos = player.global_position + offset
			
			# --- CHECK 1: THE ORACLE (Terrain) ---
			var is_wall = false
			if world_gen:
				# Check the center AND the 4 extremes of the Boss's massive body
				if world_gen.is_position_wall(candidate_pos) or \
				   world_gen.is_position_wall(candidate_pos + Vector2(required_radius, 0)) or \
				   world_gen.is_position_wall(candidate_pos - Vector2(required_radius, 0)) or \
				   world_gen.is_position_wall(candidate_pos + Vector2(0, required_radius)) or \
				   world_gen.is_position_wall(candidate_pos - Vector2(0, required_radius)):
					is_wall = true
			
			# If any part of the Boss touches a wall, skip this spot immediately
			if is_wall:
				continue 

			# --- CHECK 2: THE PHYSICS (Dynamic Obstacles) ---
			var query = PhysicsShapeQueryParameters2D.new()
			var shape = CircleShape2D.new()
			shape.radius = required_radius
			query.shape = shape
			query.transform = Transform2D(0, candidate_pos)
			query.collision_mask = 1 
			query.collide_with_bodies = true
			
			var result = space_state.intersect_shape(query)
			
			if result.is_empty():
				print("Spawner: Found guaranteed boss spawn at distance: ", current_radius)
				return candidate_pos # Guaranteed safe!
		
		# If the entire ring was blocked, push outward 100 pixels and search again
		current_radius += 100.0
	
	# Fallback ONLY if the entire 3000px radius is a solid block of terrain
	push_warning("CRITICAL: Boss could not find space. Spawning at player.")
	return player.global_position
