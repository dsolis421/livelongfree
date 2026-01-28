extends Node2D

# 1. We load the blueprint into memory so we can copy it later
@export var enemy_scene: PackedScene

# 2. Reference to the player so we know where to spawn enemies (nearby)
@onready var player = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	# Connect the timer's "timeout" signal to our function
	$Timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	if player == null:
		return
		
	# 3. Create the goblin
	var goblin = enemy_scene.instantiate()
	
	# 4. Pick a random spot
	# We take a vector pointing Right (1, 0), rotate it randomly, 
	# and stretch it out to 600 pixels (just off-screen)
	var spawn_pos = Vector2.RIGHT.rotated(randf_range(0, TAU)) * 600
	
	# 5. Set position relative to the player
	goblin.global_position = player.global_position + spawn_pos
	
	# 6. Add it to the world (Main scene)
	# We add it to 'owner' (Main) instead of 'self' so they don't move with the spawner
	get_parent().add_child(goblin)
