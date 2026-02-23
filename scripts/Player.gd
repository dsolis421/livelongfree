extends CharacterBody2D

class_name Player
signal player_died

@onready var audio = AudioManager

# --- NEW COMPONENT ---
@onready var weapon_manager = $WeaponManager

# --- SCENES ---
@export var projectile_scene: PackedScene
# @export var game_over_screen: PackedScene
# (Purge and Explosion scenes were moved to WeaponManager)

# --- NODES ---
@onready var gun_timer = $GunTimer
@onready var detection_area = $EnemyDetectionArea
@export var joystick: VirtualJoystick 

# --- STATS & CONFIG ---
@export_group("Player Stats")
@export var movement_speed: float = 300.0
@export var max_hp: float = 1.0  
var current_hp: float

# --- SCREEN SHAKE ---
@export var shake_decay: float = 5.0  
@export var meteor_shake_intensity: float = 8.0

# --- INTERNAL VARIABLES ---
var damage_multiplier: float = 1.0
var cooldown_modifier: float = 1.0 
var is_invincible: bool = false
var current_shake_strength: float = 0.0
var last_facing_direction: Vector2 = Vector2.RIGHT # Needed for Defrag

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
		var bonus_hp = buffer_level
		max_hp += bonus_hp
		current_hp += bonus_hp
		print("Repo Upgrade: Player Buffer Applied (+", bonus_hp, " HP)")
	
	# B. DAMAGE (Multiplier)
	var damage_level = GameData.get_upgrade_level("damage")
	if damage_level > 0:
		damage_multiplier = 1.0 + (damage_level * 0.5)
		print("Repo Upgrade: Player Damage Multiplier set to ", damage_multiplier)

	# C. MAGNET (Collection Range)
	var magnet_level = GameData.get_upgrade_level("magnet")
	if magnet_level > 0:
		var magnet_shape = get_node_or_null("MagnetArea/CollisionShape2D")
		if magnet_shape and magnet_shape.shape is CircleShape2D:
			magnet_shape.shape.radius *= (1.0 + (magnet_level * 0.1))
			print("Repo Upgrade: Magnet Radius Increased to ", magnet_shape.shape.radius)

# --- PHYSICS LOOP ---
func _physics_process(delta: float) -> void:
	move()
	handle_screen_shake(delta)

func move() -> void:
	var direction = get_game_input()
	
	if direction.length() > 0:
		velocity = direction * movement_speed
		# Cache the last direction for weapons like Defrag that shoot straight!
		last_facing_direction = direction.normalized() 
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func get_game_input() -> Vector2:
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input == Vector2.ZERO:
		var v_joy = get_tree().get_first_node_in_group("virtual_joystick")
		if v_joy and v_joy.has_method("get_output"):
			input = v_joy.get_output()
	return input

# --- COMBAT LOGIC ---
func take_damage(amount: float = 1.0) -> void:
	if GameManager.is_game_over: return
	
	if is_invincible:
		return 

	current_hp -= amount
	print("Player Hit! HP: ", current_hp, " / ", max_hp)
	
	if current_hp <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	
	await get_tree().create_timer(0.1).timeout
	
	if GameManager.is_game_over:
		queue_free()
		return
	## Orphan the camera so GameOver renders in place.
	var camera = $Camera2D
	if camera:
		remove_child(camera)
		get_parent().add_child(camera)
		camera.global_position = global_position
	GameManager.save_game()
	GameManager.on_player_died()

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
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	
	# 2. Stats
	bullet.damage = 1.0 * damage_multiplier 
	
	# 3. Apply Ricochet
	var ricochet_level = GameData.get_upgrade_level("ricochet")
	if ricochet_level > 0:
		bullet.bounce_count = ricochet_level
		bullet.bounce_range = 400.0 
	
	# 4. Direction
	var direction = (target.global_position - global_position).normalized()
	bullet.direction = direction
	bullet.rotation = direction.angle()
	
	# 5. Audio
	if audio:
		audio.play_sfx("weapon_fire")

# --- LEVEL UP & POWER UPS ---
func apply_upgrade(type: String) -> void:
	match type:
		"movement_speed":
			if movement_speed >= MAX_SPEED: return
			movement_speed += 20.0
		"cooldown":
			if cooldown_modifier <= MIN_COOLDOWN_MODIFIER: return
			cooldown_modifier -= 0.03
			if cooldown_modifier < MIN_COOLDOWN_MODIFIER:
				cooldown_modifier = MIN_COOLDOWN_MODIFIER
			$GunTimer.wait_time = BASE_COOLDOWN_TIME * cooldown_modifier

# ALL POWER WEAPON LOGIC IS DELEGATED HERE!
func activate_power_weapon(type: String) -> void:
	if weapon_manager:
		weapon_manager.activate_power_weapon(type)
	else:
		print("ERROR: WeaponManager node not found!")

# --- SCREEN SHAKE (Used by Weapon Manager) ---
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
