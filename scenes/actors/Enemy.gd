extends CharacterBody2D

class_name Enemy
var hp: int = 3
@export var movement_speed: float = 150.0 # Slower than player (300)
@export var loot_scene: PackedScene

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


func _on_hitbox_body_entered(body: Node2D) -> void:
	# Only kill it if it is the Player!
	if body.name == "Player":
		body.die()

func take_damage(amount: int = 1) -> void:
	hp -= amount
	# Optional: Add a "Flash White" or "Knockback" effect here later!
	
	if hp <= 0:
		die()

func die() -> void:
	GameManager.kills += 1
	
	# 1. Roll for Drop Chance (1 in 10 chance)
	# randf() gives a random number between 0.0 and 1.0
	if randf() <= 0.10: 
		spawn_loot()
		
	queue_free()

func spawn_loot() -> void:
	if loot_scene == null:
		return
		
	# 1. Simple Rarity Roll
	var roll = randf()
	var type = 0 
	if roll < 0.01: type = 3
	elif roll < 0.06: type = 2
	elif roll < 0.26: type = 1
	
	# 2. Make the Gem
	var gem = loot_scene.instantiate()
	gem.setup(type)
	
	# 3. CRITICAL FIX: Add it to the absolute root of the current scene
	# This ensures it doesn't care about the Enemy dying
	get_tree().current_scene.add_child(gem)
	
	# 4. Set position AFTER adding it (prevents drift)
	gem.global_position = global_position
