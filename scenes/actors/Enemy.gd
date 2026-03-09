extends CharacterBody2D

class_name Enemy

enum EnemyState { SPAWNING, ACTIVE, DEAD }
var enemy_status: EnemyState = EnemyState.ACTIVE

enum EnemyRole { 
	FODDER,   # Default, small enemies
	ELITE,    # Tougher, maybe special abilities
	BOSS      # The big bad
}

# const LOOT_SCENE = preload("res://scenes/loot/Gem.tscn")

@export_group("Loot Settings")
@export var loot_scene: PackedScene
@export var drop_chance: float = 1.0 
@export var special_drop_chance: float = 1.0 
@export var special_drop_scene: PackedScene 
@export var available_drops: Array[String] = ["SigKill", "Purge", "Defrag"] 
@export var is_coin_dropper: bool = false

@export_group("Enemy Settings")
@export var hp: int = 3
@export var movement_speed: float = 115.0 
@export var damage: int = 1 
@export var xp_value: int = 1 
@export var knockback_resistance: float = 0.3 
@export var death_effect: PackedScene
@export var role: EnemyRole = EnemyRole.FODDER

# We track knockback separately so we can decay it over time
var knockback_velocity: Vector2 = Vector2.ZERO

@export var visual = Node2D
@onready var player = get_tree().get_first_node_in_group("player")
@onready var left_ray = $LeftRay
@onready var right_ray = $RightRay
@onready var audio = AudioManager
@onready var collision_shape = $CollisionShape2D

func _ready() -> void:
	if visual == null:
		if has_node("ColorRect"):
			visual = $ColorRect
		elif has_node("Polygon2D"):
			visual = $Polygon2D
	
	if visual and visual.material:
		visual.material = visual.material.duplicate()
	# --- 3. APPLY IDENTITY BASED ON ROLE ---
	# We assign the group dynamically. This prevents inheritance conflicts.
	match role:
		EnemyRole.FODDER:
			add_to_group("fodder")
		EnemyRole.ELITE:
			add_to_group("elite")
		EnemyRole.BOSS:
			add_to_group("boss")
			
			# EXTEND WHISKERS (Logic moved here directly)
			if left_ray: left_ray.target_position *= 4.0
			if right_ray: right_ray.target_position *= 4.0
	# --- 4. KEEP "ENEMY" GROUP ---
	# Ensures generic collision logic (bullets hitting enemies) always works
	if enemy_status == EnemyState.ACTIVE and not is_in_group("enemy"):
		add_to_group("enemy")
		
	# --- 5. NEW: APPLY RUN DIFFICULTY ---
	if GameManager:
		if is_in_group("elite") or is_in_group("boss"):
			hp = int(hp * GameManager.run_enemy_hp_mult)
		movement_speed = movement_speed + GameManager.run_enemy_speed_mod

func start_wall_spawn(wall_position: Vector2, floor_position: Vector2, spawn_duration: float = 1.0) -> void:
	enemy_status = EnemyState.SPAWNING
	global_position = wall_position
	
	# Become a ghost (No targeting, no physics)
	if is_in_group("enemy"):
		remove_from_group("enemy")
	collision_shape.set_deferred("disabled", true)
	
	# The Squeeze: Compress the visual code to fit in the wall
	if visual:
		visual.scale = Vector2(0.1, 0.1) 
		# Set shader to fully glitched
		if visual.material:
			visual.material.set_shader_parameter("progress", 0.0) 
		
	# The Peel: Tween out to the floor and decompress
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", floor_position, spawn_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.0, 1.0), spawn_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Animate the shader from 0.0 (glitch) to 1.0 (solid)
		if visual.material:
			tween.tween_property(visual.material, "shader_parameter/progress", 1.2, spawn_duration)
	
	# When finished, wake up!
	tween.chain().tween_callback(finish_spawning)

func finish_spawning() -> void:
	enemy_status = EnemyState.ACTIVE
	add_to_group("enemy")
	collision_shape.set_deferred("disabled", false)
	
func _physics_process(delta: float) -> void:
# --- NEW GUARD: Don't move if we are stuck in the wall spawning! ---
	if enemy_status != EnemyState.ACTIVE: return
	
	if player == null: return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > 2000.0:
		if not is_in_group("boss"):
			queue_free()
			return
			
	var direction = (player.global_position - global_position).normalized()
	var avoidance = Vector2.ZERO
	var avoidance_force = 30.0 
	
	var left_hit = left_ray.is_colliding()
	var right_hit = right_ray.is_colliding()
	
	if left_hit: avoidance += transform.y * avoidance_force
	if right_hit: avoidance -= transform.y * avoidance_force
	if left_hit and right_hit: avoidance += transform.y * avoidance_force 
	
	var desired_velocity = (direction + avoidance).normalized() * movement_speed
	
	velocity = desired_velocity + knockback_velocity
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 5 * delta)
	
	move_and_slide()
	
	if avoidance == Vector2.ZERO:
		look_at(player.global_position)
	else:
		var look_target = global_position + velocity
		look_at(look_target)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if enemy_status != EnemyState.ACTIVE: return # Guard
	
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)

func take_damage(amount: int) -> void:
	if enemy_status != EnemyState.ACTIVE: return # Guard: Invincible while spawning
	
	hp -= amount
	if hp <= 0:
		die()
		
func take_knockback(source_position: Vector2, force: float) -> void:
	if enemy_status != EnemyState.ACTIVE: return # Guard: No knockback while spawning
	
	var direction = global_position - source_position
	direction = direction.normalized()
	var final_force = force * (1.0 - knockback_resistance)
	
	audio.play_sfx("enemy_hit")
	knockback_velocity = direction * final_force

func die() -> void:
	spawn_death_effect()
	AudioManager.play_sfx("enemy_death")
	if GameManager:
		GameManager.kills += 1
		
	# 1. Try to drop Special Loot first
	var dropped_special = spawn_special_loot()
	
	# 2. If no special loot dropped, try to drop Standard Loot
	if not dropped_special:
		spawn_standard_loot()

	queue_free()

func spawn_special_loot() -> bool:
	# If this specific enemy doesn't have special loot assigned, fail immediately
	if special_drop_scene == null:
		return false
		
	# Roll the dice against the Inspector's special_drop_chance!
	if randf() <= special_drop_chance:
		var pickup = special_drop_scene.instantiate()
		get_tree().current_scene.call_deferred("add_child", pickup)
		pickup.set_deferred("global_position", global_position)
		if available_drops.size() > 0:
			var chosen_type = available_drops.pick_random()
			pickup.call_deferred("setup", chosen_type)
		return true # Success! We dropped special loot.
		
	return false # We rolled the dice and lost.

func spawn_standard_loot() -> void:
	if GameManager.is_boss_active and is_in_group("fodder"):
		return

	if not loot_scene:
		push_warning("Enemy tried to drop loot, but no loot_scene was assigned!")
		return
		
	if randf() > drop_chance:
		return

	var loot = loot_scene.instantiate()

	if is_coin_dropper:
		loot.setup(loot.TYPE.GOLD)
	else:
		var roll = randf() 
		if roll < 0.05:      loot.setup(loot.TYPE.LEGENDARY)
		elif roll < 0.1:     loot.setup(loot.TYPE.EPIC)
		elif roll < 0.25:    loot.setup(loot.TYPE.RARE)
		else:                loot.setup(loot.TYPE.COMMON)

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
