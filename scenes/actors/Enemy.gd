extends CharacterBody2D

class_name Enemy

enum EnemyRole { 
	FODDER,   # Default, small enemies
	ELITE,    # Tougher, maybe special abilities
	BOSS      # The big bad
}

const LOOT_SCENE = preload("res://scenes/loot/Gem.tscn")

@export_group("Loot Settings")
@export var hp: int = 3
@export var movement_speed: float = 150.0 
@export var damage: int = 1 
@export var xp_value: int = 1 
@export var loot_scene: PackedScene
@export var drop_chance: float = 1.0 
@export var knockback_resistance: float = 0.0 
@export var death_effect: PackedScene
@export var special_drop_chance: float = 1.0 
@export var special_drop_scene: PackedScene 
@export var available_drops: Array[String] = ["SigKill", "Purge"] 
@export var role: EnemyRole = EnemyRole.FODDER

# We track knockback separately so we can decay it over time
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var visual = $ColorRect
@onready var player = get_tree().get_first_node_in_group("player")
@onready var left_ray = $LeftRay
@onready var right_ray = $RightRay

func _ready() -> void:
	# --- 3. APPLY IDENTITY BASED ON ROLE ---
	# We assign the group dynamically. This prevents inheritance conflicts.
	
	match role:
		EnemyRole.FODDER:
			add_to_group("fodder")
			# Optional: Scale down or set low HP here if generic
			
		EnemyRole.ELITE:
			add_to_group("elite")
			# Optional: Add a visual glow or boost HP
			
		EnemyRole.BOSS:
			add_to_group("boss")
			print("Role is BOSS. Extending whiskers...")
			
			# EXTEND WHISKERS (Logic moved here directly)
			if left_ray: left_ray.target_position *= 4.0
			if right_ray: right_ray.target_position *= 4.0

	# --- 4. KEEP "ENEMY" GROUP ---
	# Ensures generic collision logic (bullets hitting enemies) always works
	if not is_in_group("enemy"):
		add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if player == null: return
	# If we are too far away, vanish instantly.
	# 2000px is about 2-3 screens away.
	var dist_to_player = global_position.distance_to(player.global_position)
	
	if dist_to_player > 2000.0:
		# CRITICAL: Do not despawn the Boss!
		if not is_in_group("boss"):
			queue_free()
			return
	# 1. Base Direction (To Player)
	var direction = (player.global_position - global_position).normalized()
	
	# 2. Avoidance Logic
	var avoidance = Vector2.ZERO
	var avoidance_force = 15.0 
	
	var left_hit = left_ray.is_colliding()
	var right_hit = right_ray.is_colliding()
	
	if left_hit:
		avoidance += transform.y * avoidance_force
	
	if right_hit:
		avoidance -= transform.y * avoidance_force
		
	# --- THE FIX: THE TIE-BREAKER ---
	# If BOTH rays hit (head-on collision), the forces cancel out to zero.
	# We must force a turn. We default to turning Right.
	if left_hit and right_hit:
		avoidance += transform.y * avoidance_force # Extra push Right
	
	# 3. Combine Vectors
	var desired_velocity = (direction + avoidance).normalized() * movement_speed
	
	# 4. Apply Knockback (The Fix)
	# Add the knockback to the movement, then slowly reduce it (decay)
	velocity = desired_velocity + knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10 * delta)
	
	move_and_slide()
	
	# 5. Rotation Logic
	if avoidance == Vector2.ZERO:
		look_at(player.global_position)
	else:
		# Look where we are going so the rays sweep the corner
		# Use 'velocity' here so it accounts for the avoidance turn
		var look_target = global_position + velocity
		look_at(look_target)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(1)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()
		
func take_knockback(source_position: Vector2, force: float) -> void:
	# 1. Calculate direction AWAY from the bullet
	var direction = global_position - source_position
	direction = direction.normalized()

	# 2. Calculate force
	var final_force = force * (1.0 - knockback_resistance)

	# 3. Apply the kick
	# We set the variable here, and _physics_process handles the movement
	knockback_velocity = direction * final_force

func die() -> void:
	spawn_death_effect()
	if GameManager:
		GameManager.kills += 1
		
	if special_drop_scene != null:
		spawn_special_loot()
	else:
		spawn_standard_loot()

	queue_free()

func spawn_special_loot() -> void:
	if randf() <= special_drop_chance:
		var pickup = special_drop_scene.instantiate()
		get_tree().current_scene.call_deferred("add_child", pickup)
		pickup.set_deferred("global_position", global_position)
		if available_drops.size() > 0:
			var chosen_type = available_drops.pick_random()
			pickup.call_deferred("setup", chosen_type)

func spawn_standard_loot() -> void:
	if GameManager.is_boss_active and is_in_group("fodder"):
		return

	var loot = LOOT_SCENE.instantiate()

	if randf() < 0.10:
		loot.setup(loot.TYPE.GOLD)
	else:
		var roll = randf() # Returns 0.0 to 1.0
		
		if roll < 0.05:      # 1% Chance
			loot.setup(loot.TYPE.LEGENDARY)
		elif roll < 0.1:    # 4% Chance (0.01 to 0.05)
			loot.setup(loot.TYPE.EPIC)
		elif roll < 0.25:    # 20% Chance (0.05 to 0.25)
			loot.setup(loot.TYPE.RARE)
		else:                # 75% Chance (The rest)
			loot.setup(loot.TYPE.COMMON)

	get_tree().current_scene.call_deferred("add_child", loot)
	loot.set_deferred("global_position", global_position)
	
func spawn_death_effect() -> void:
	if death_effect:
		var effect = death_effect.instantiate()
		# get_tree().current_scene.add_child(effect)
		# effect.global_position = global_position
		get_parent().add_child(effect)
		effect.global_position = global_position
		if effect is GPUParticles2D:
			effect.process_material.color = Color.WHITE
			effect.restart()
			effect.emitting = true
