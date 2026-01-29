extends Node2D

@export var enemy_scene: PackedScene

func _on_timer_timeout() -> void:
	# 1. Find Player
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# 2. Create Enemy
	var enemy = enemy_scene.instantiate()

	# 3. Calculate Position (Simple Math)
	# Pick a random direction (0 to 360 degrees)
	var random_angle = randf() * TAU
	# Create a vector 600 pixels long in that direction
	var offset = Vector2.RIGHT.rotated(random_angle) * 1000
	
	# 4. Place it relative to the player
	enemy.global_position = player.global_position + offset

	# 5. Add to the World
	get_tree().current_scene.add_child(enemy)
