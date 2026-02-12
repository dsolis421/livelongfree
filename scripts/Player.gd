extends CharacterBody2D

class_name Player
signal player_died

# --- SCENES ---
@export var projectile_scene: PackedScene
@export var game_over_screen: PackedScene
@export var explosion_scene: PackedScene
@export var nuke_scene: PackedScene

# --- NODES ---
@onready var gun_timer = $GunTimer
@onready var sprite = $AnimatedSprite2D
@onready var detection_area = $EnemyDetectionArea
@export var joystick: VirtualJoystick 

# --- STATS & CONFIG ---
@export_group("Player Stats")
@export var movement_speed: float = 300.0
@export var max_hp: float = 1.0  # Default starting HP
var current_hp: float

# --- SPELL CONFIGURATION ---
@export_group("Spell Stats")
@export var invincible_duration: float = 5.0
@export var nuke_damage: int = 50
@export var meteor_damage: int = 10
@export var meteor_impact_radius: float = 150.0 
# --- SCREEN SHAKE ---
@export var shake_decay: float = 5.0  
@export var meteor_shake_intensity: float = 8.0

# --- INTERNAL VARIABLES ---
var damage_multiplier: float = 1.0
var cooldown_modifier: float = 1.0 
var is_invincible: bool = false
var current_shake_strength: float = 0.0

const BASE_COOLDOWN_TIME: float = 0.5 
const MIN_COOLDOWN_MODIFIER: float = 0.2 
const MAX_SPEED: float = 500.0 

# --- INITIALIZATION ---
func _ready() -> void:
	# 1. Initialize Health
	current_hp = max_hp
	
	# 2. Load Store Upgrades
	_apply_global_upgrades()

func _apply_global_upgrades() -> void:
	# A. BUFFER (Extra HP)
	var buffer_level = GameData.get_upgrade_level("buffer")
	if buffer_level > 0:
		var bonus_hp = buffer_level * 2
		max_hp += bonus_hp
		current_hp += bonus_hp
		print("Repo Upgrade: Buffer Applied (+", bonus_hp, " HP)")
	
	# B. DAMAGE (Multiplier)
	var damage_level = GameData.get_upgrade_level("damage")
	if damage_level > 0:
		# Example: Level 1 = 1.1x Damage
		damage_multiplier = 1.0 + (damage_level * 0.5)
		print("Repo Upgrade: Damage Multiplier set to ", damage_multiplier)

	# C. MAGNET (Collection Range)
	var magnet_level = GameData.get_upgrade_level("magnet")
	if magnet_level > 0:
		# NOTE: This assumes you have an Area2D named "MagnetArea" for XP.
		# If you don't have one yet, this check prevents a crash.
		var magnet_shape = get_node_or_null("MagnetArea/CollisionShape2D")
		if magnet_shape and magnet_shape.shape is CircleShape2D:
			magnet_shape.shape.radius *= (1.0 + (magnet_level * 0.1))
			print("Repo Upgrade: Magnet Radius Increased to ", magnet_shape.shape.radius)

# --- PHYSICS LOOP ---
func _physics_process(delta: float) -> void:
	move()
	handle_screen_shake(delta)
	update_animation()
	
func move() -> void:
	var direction = get_game_input()
	
	if direction.length() > 0:
		velocity = direction * movement_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func update_animation() -> void:
	if not sprite: return

	if velocity.length() > 0:
		sprite.play("run") 
		sprite.rotation = velocity.angle()
	else:
		sprite.play("idle") 

func get_game_input() -> Vector2:
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input == Vector2.ZERO:
		var v_joy = get_tree().get_first_node_in_group("virtual_joystick")
		if v_joy and v_joy.has_method("get_output"):
			input = v_joy.get_output()
	return input

# --- COMBAT LOGIC ---

# UPDATED: Accepts float and subtracts HP
func take_damage(amount: float = 1.0) -> void:
	# If the boss is dead, the game is over (Victory state). Don't take damage.
	if GameManager.is_game_over:
		return
	
	if is_invincible:
		print("Damage Blocked! (Invincible)")
		return 

	current_hp -= amount
	print("Player Hit! HP: ", current_hp, " / ", max_hp)
	
	if current_hp <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	await get_tree().create_timer(0.1).timeout
	if GameManager.is_game_over:
		print("Player died, but Victory was already triggered. cancelling Game Over.")
		queue_free()
		return
	
	GameManager.on_player_died()
	
	player_died.emit()
	print("Player has died!")
	GameManager.save_game()
	
	if game_over_screen:
		var screen = game_over_screen.instantiate()
		get_tree().root.add_child(screen)

	get_tree().paused = true
	queue_free()

func get_nearest_enemy():
	var nearby_enemies = detection_area.get_overlapping_bodies()
	if nearby_enemies.is_empty(): return null
	
	var nearest_enemy = null
	var min_dist = INF
	
	for enemy in nearby_enemies:
		if not enemy.is_in_group("enemy"): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_enemy = enemy
			
	return nearest_enemy
	
func _on_gun_timer_timeout() -> void:
	var target = get_nearest_enemy()
	if target == null: return 
	
	# 1. Create Bullet
	var bullet = projectile_scene.instantiate()
	
	# 2. CRITICAL FIX: Add to scene FIRST
	# This tells Godot exactly which coordinate space the bullet lives in.
	get_parent().add_child(bullet)
	
	# 3. NOW set the position
	# Since it's in the tree, "global_position" now calculates correctly relative to the world.
	bullet.global_position = global_position
	
	# 4. Setup Stats
	bullet.damage = 1.0 * damage_multiplier 
	
	# 5. Calculate Direction
	var direction = (target.global_position - global_position).normalized()
	bullet.direction = direction
	bullet.rotation = direction.angle()

# --- LEVEL UP & POWER UPS ---

func apply_upgrade(type: String) -> void:
	match type:
		"movement_speed":
			if movement_speed >= MAX_SPEED: return
			movement_speed += 20.0
			print("movement speed upgraded to: ", movement_speed)
		"cooldown":
			if cooldown_modifier <= MIN_COOLDOWN_MODIFIER: return
			cooldown_modifier -= 0.03
			if cooldown_modifier < MIN_COOLDOWN_MODIFIER:
				cooldown_modifier = MIN_COOLDOWN_MODIFIER
			$GunTimer.wait_time = BASE_COOLDOWN_TIME * cooldown_modifier
			print("fire faster upgrade to: ", cooldown_modifier)

func activate_power_weapon(type: String) -> void:
	match type:
		"invincible": cast_invincible()
		"Purge": cast_nuke()
		"SigKill": cast_meteor()

func cast_invincible() -> void:
	if is_invincible: return
	is_invincible = true
	var original_modulate = self.modulate
	self.modulate = Color(2, 2, 0, 1) 
	await get_tree().create_timer(invincible_duration).timeout
	is_invincible = false
	self.modulate = original_modulate

func cast_nuke() -> void:
	if nuke_scene:
		var nuke_vfx = nuke_scene.instantiate()
		get_tree().root.add_child(nuke_vfx) 
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(nuke_damage)

func cast_meteor() -> void:
	for i in range(3):
		fire_one_meteor()
		await get_tree().create_timer(0.2).timeout

func fire_one_meteor() -> void:
	if not explosion_scene: return
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	if all_enemies.is_empty(): return
		
	# Find visible enemies logic...
	var visible_enemies = []
	var screen_size = get_viewport_rect().size
	var player_pos = global_position
	var max_dx = (screen_size.x / 2) + 100 
	var max_dy = (screen_size.y / 2) + 100
	
	for enemy in all_enemies:
		var dx = abs(enemy.global_position.x - player_pos.x)
		var dy = abs(enemy.global_position.y - player_pos.y)
		if dx < max_dx and dy < max_dy:
			visible_enemies.append(enemy)
	
	var target = null
	if visible_enemies.size() > 0:
		target = visible_enemies.pick_random()
	else:
		target = all_enemies[0]

	var boom = explosion_scene.instantiate()
	get_tree().current_scene.add_child(boom) 
	var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	boom.global_position = target.global_position + offset
	apply_shake(meteor_shake_intensity)
	
	# Apply damage to enemies in radius
	var hit_enemies = get_tree().get_nodes_in_group("enemy")
	for e in hit_enemies:
		if e.global_position.distance_to(boom.global_position) < meteor_impact_radius:
			if e.has_method("take_damage"):
				e.take_damage(meteor_damage)

func handle_screen_shake(delta: float) -> void:
	if current_shake_strength > 0:
		current_shake_strength = lerp(current_shake_strength, 0.0, shake_decay * delta)      
		var camera = $Camera2D
		if camera:
			var random_offset = Vector2(
				randf_range(-current_shake_strength, current_shake_strength),
				randf_range(-current_shake_strength, current_shake_strength)
			)
			camera.offset = random_offset
			if current_shake_strength < 0.1:
				current_shake_strength = 0
				if camera: camera.offset = Vector2.ZERO
				
func apply_shake(amount: float) -> void:
	current_shake_strength = amount

func _on_player_died() -> void:
	pass
