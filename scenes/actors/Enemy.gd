extends CharacterBody2D

class_name Enemy
@export_group("Loot Settings")
@export var hp: int = 3
@export var movement_speed: float = 150.0 # Slower than player (300)
@export var damage: int = 1 # How much it hurts the player (for future use)
@export var xp_value: int = 1 # How much XP it drops (via gems)
@export var loot_scene: PackedScene
@export var drop_chance: float = 1.0 # Default 100% (1.0), but we will change this!
@export var knockback_resistance: float = 0.0 
@export var death_effect: PackedScene
@export var special_drop_chance: float = 1.0 # Chance to drop PowerUp/Spell
@export var special_drop_scene: PackedScene  # The PowerUp OR Spell Scene
@export var available_drops: Array[String] = ["meteor", "nuke"] # Default list

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
		if body.has_method("take_damage"):
			body.take_damage(1)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		# 1. Visuals
		spawn_death_effect()
		# Check your script for the exact name. It might be spawn_gem() or drop_loot()
		call_deferred("spawn_loot")
		# 3. Cleanup
		queue_free()
		
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
	# 1. ATTEMPT GEM DROP (XP)
	# Only run this if a loot_scene is actually assigned in Inspector!
	if loot_scene != null:
		if randf() <= drop_chance:
			# ... [Insert your existing Gem Rarity Logic here] ...
			# ... (Instantiate gem, call_deferred, etc.) ...
			var roll = randf()
			var type = 0 
			if roll < 0.01: type = 3
			elif roll < 0.06: type = 2
			elif roll < 0.26: type = 1
			
			var gem = loot_scene.instantiate()
			gem.setup(type)
			get_tree().current_scene.call_deferred("add_child", gem)
			gem.set_deferred("global_position", global_position)

	# 2. ATTEMPT SPECIAL DROP (Weapon/Spell)
	# Only run this if a special scene is assigned!
	if special_drop_scene != null:
		if randf() <= special_drop_chance:
			print("---SPAWNING SPECIAL DROP")
			print("---Name: ", name)
			print("---Available Drop List: ", available_drops)
			
			var pickup = special_drop_scene.instantiate()
			
			# Add to scene FIRST so it exists
			get_tree().current_scene.call_deferred("add_child", pickup)
			pickup.set_deferred("global_position", global_position)
			
			# NOW we decide what it is
			# If I am a Brute, maybe I only drop Weapons?
			# If I am a Phantom, maybe I only drop Spells?
			
			# For now, let's pick randomly from a list suitable for this enemy
			# We can create a new export variable for this list!
			var chosen_type = available_drops.pick_random()
			print("***I Picked ", chosen_type)
			pickup.call_deferred("setup", chosen_type)

func spawn_death_effect() -> void:
	if death_effect:
		# 1. Create the object
		var effect = death_effect.instantiate()
		# 2. Add to scene FIRST (Let it initialize)
		get_tree().current_scene.add_child(effect)
		# 3. Move it to the correct spot SECOND
		effect.global_position = global_position
		# 4. KICKSTART (Crucial!)
		# Since it might have tried to play at (0,0) the moment we added it,
		# we force it to restart now that it is in the right place.
		if effect is GPUParticles2D:
			effect.restart()
			effect.emitting = true
