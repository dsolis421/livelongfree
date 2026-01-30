extends CharacterBody2D

class_name Enemy
@export var hp: int = 3
@export var movement_speed: float = 150.0 # Slower than player (300)
@export var damage: int = 1 # How much it hurts the player (for future use)
@export var xp_value: int = 1 # How much XP it drops (via gems)
@export var loot_scene: PackedScene
@export var drop_chance: float = 1.0 # Default 100% (1.0), but we will change this!
@export var knockback_resistance: float = 0.0 

var knockback_velocity: Vector2 = Vector2.ZERO

@onready var visual = $ColorRect
@onready var player = get_tree().get_first_node_in_group("player")


#func _ready() -> void:
	# 1. Find the Player when the enemy spawns
	# We ask the "Scene Tree" to find the first node in the 'player' group
#	player_reference = get_tree().get_first_node_in_group("player")
	
func _physics_process(delta: float) -> void:
	if player:
		# Normal movement toward player
		var direction = global_position.direction_to(player.global_position)
		var movement = direction * movement_speed

		# Combine Movement + Knockback
		velocity = movement + knockback_velocity
		move_and_slide()

		# Decay the knockback (Friction)
		# This makes them slide to a stop smoothly
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10 * delta)

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Only kill it if it is the Player!
	if body.name == "Player":
		body.die()

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		die()
		
func take_knockback(source_position: Vector2, force: float) -> void:
	# 1. Calculate direction AWAY from the bullet
	var direction = global_position - source_position
	direction = direction.normalized()

	# 2. Calculate actual force (reduced by resistance)
	# If resistance is 0.8, we only take 20% of the force.
	var final_force = force * (1.0 - knockback_resistance)

	# 3. Apply the kick
	knockback_velocity = direction * final_force

func die() -> void:
	if GameManager:
		GameManager.kills += 1
	spawn_loot()
	queue_free()

func spawn_loot() -> void:
	if loot_scene == null:
		return
	if randf() > drop_chance:
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
	
	# 1. Add to scene deferred (wait for physics to finish)
	get_tree().current_scene.call_deferred("add_child", gem)

	# 2. Set Position deferred (wait for it to be in the tree)
	# We pass the CURRENT global_position to the gem's "global_position" property
	gem.set_deferred("global_position", global_position)
