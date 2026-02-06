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
		
	# --- NEW: 360 ROTATION ---
	# Only rotate if we are actually moving, otherwise they snap to 0 degrees when stopped
	if velocity.length() > 0:
		rotation = velocity.angle()

func _on_hitbox_body_entered(body: Node2D) -> void:
	
	# Only kill it if it is the Player!
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(1)

func take_damage(amount: int) -> void:
	print("---I took damage from something!---")
	print_stack()
	print("-----------------------------------")
	hp -= amount
	if hp <= 0:
		# STOP! Do not queue_free here.
		# Hand control over to the die() function.
		# This allows the Boss script to intercept this moment!
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
	# 1. Visuals & Score
	spawn_death_effect()
	if GameManager:
		GameManager.kills += 1
		
	# 2. DECISION TIME: What do I drop?
	# If I have a special drop (like a Brute), do that.
	if special_drop_scene != null:
		spawn_special_loot()
	# Otherwise, do the standard Coin/Gem drop (like a Goblin).
	else:
		spawn_standard_loot()

	queue_free()

func spawn_special_loot() -> void:
	# Check the chance (usually 1.0 for Brutes)
	if randf() <= special_drop_chance:
		var pickup = special_drop_scene.instantiate()
		
		# Add to scene safely
		get_tree().current_scene.call_deferred("add_child", pickup)
		pickup.set_deferred("global_position", global_position)
		
		# Pick a random item (Nuke, Magnet, etc.)
		if available_drops.size() > 0:
			var chosen_type = available_drops.pick_random()
			# We use call_deferred to be safe, just like with position
			pickup.call_deferred("setup", chosen_type)

func spawn_standard_loot() -> void:
	# 1. The Gatekeeper: Stop fodder from dropping loot during Boss fights
	if GameManager.is_boss_active and is_in_group("fodder"):
		return

	# 2. Load the scene (Using the path we confirmed works!)
	var loot = load("res://scenes/loot/Gem.tscn").instantiate()
	
	# 3. Coin vs Gem Logic
	if randf() < 0.10: # 10% Chance for Coin
		loot.setup(loot.TYPE.GOLD)
	else:
		loot.setup(loot.TYPE.COMMON)

	# 4. Add to scene safely (The fix for "Ghost Gems")
	get_tree().current_scene.call_deferred("add_child", loot)
	loot.set_deferred("global_position", global_position)
	
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
