extends Node2D

# --- THE MENU ---
# We now have slots for all 3 types
@export var goblin_scene: PackedScene
@export var sprinter_scene: PackedScene
@export var brute_scene: PackedScene

func _on_timer_timeout() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# 1. DECIDE WHICH ENEMY TO SPAWN
	var enemy_choice = pick_enemy_by_level()
	if enemy_choice == null:
		return

	# 2. INSTANTIATE IT
	var enemy = enemy_choice.instantiate()

	# 3. CALCULATE POSITION (Your existing "Donut" math)
	var viewport_size = get_viewport_rect().size
	var safe_distance = max(viewport_size.x, viewport_size.y) / 2 + 1000
	var angle = randf() * TAU
	var distance = randf_range(safe_distance, safe_distance + 300)
	var spawn_offset = Vector2(cos(angle), sin(angle)) * distance
	var spawn_pos = player.global_position + spawn_offset
	
	# 4. ADD TO WORLD
	enemy.global_position = spawn_pos
	get_tree().current_scene.add_child(enemy)

# --- THE BRAIN ---
func pick_enemy_by_level() -> PackedScene:
	var current_level = GameManager.level
	var roll = randf() # Returns 0.0 to 1.0
	
	# LEVEL 6+: Danger Zone (Brutes, Sprinters, Goblins)
	if current_level >= 6:
		if roll < 0.1: return brute_scene     # 10% Chance
		elif roll < 0.4: return sprinter_scene # 30% Chance
		else: return goblin_scene              # 60% Chance
		
	# LEVEL 3+: Speed Zone (Sprinters, Goblins)
	elif current_level >= 3:
		if roll < 0.2: return sprinter_scene   # 20% Chance
		else: return goblin_scene              # 80% Chance
		
	# LEVEL 1-2: Tutorial Zone (Goblins only)
	else:
		return goblin_scene
