extends CharacterBody2D

class_name Enemy

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
@export var available_drops: Array[String] = ["meteor", "nuke"] 

# We track knockback separately so we can decay it over time
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var visual = $ColorRect
@onready var player = get_tree().get_first_node_in_group("player")
@onready var left_ray = $LeftRay
@onready var right_ray = $RightRay

func _physics_process(delta: float) -> void:
	if player == null: return
	
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

	var loot = load("res://scenes/loot/Gem.tscn").instantiate()
	
	if randf() < 0.10: 
		loot.setup(loot.TYPE.GOLD)
	else:
		loot.setup(loot.TYPE.COMMON)

	get_tree().current_scene.call_deferred("add_child", loot)
	loot.set_deferred("global_position", global_position)
	
func spawn_death_effect() -> void:
	if death_effect:
		var effect = death_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
		if effect is GPUParticles2D:
			effect.restart()
			effect.emitting = true
