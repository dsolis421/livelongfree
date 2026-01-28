extends CharacterBody2D
class_name Enemy

@export var movement_speed: float = 150.0 # Slower than player (300)

var player_reference: Player

func _ready() -> void:
	# 1. Find the Player when the enemy spawns
	# We ask the "Scene Tree" to find the first node in the 'player' group
	player_reference = get_tree().get_first_node_in_group("player")
	
func _physics_process(_delta: float) -> void:
	if player_reference:
		# 2. Calculate direction to the player
		# (Target Position - My Position) gives us the vector pointing there
		var direction = global_position.direction_to(player_reference.global_position)
		
		# 3. Move
		velocity = direction * movement_speed
		move_and_slide()
