extends Node2D
class_name WeaponManager

@onready var player = get_parent()
@onready var audio = AudioManager

# --- POWER WEAPON SCENES ---
@export var purge_scene: PackedScene
@export var explosion_scene: PackedScene
@export var defrag_scene: PackedScene

# --- SPELL STATS ---
@export var invincible_duration: float = 10.0
@export var purge_damage: int = 20
@export var meteor_damage: int = 10
@export var meteor_impact_radius: float = 150.0
@export var defrag_damage: int = 20

func activate_power_weapon(type: String) -> void:
	match type:
		"SysRoot": cast_invincible()
		"Purge": cast_purge()
		"SigKill": cast_meteor()
		"Defrag": cast_defrag()

# --- SYSROOT (INVINCIBLE) ---
func cast_invincible() -> void:
	if player.is_invincible: return
	player.is_invincible = true
	var original_modulate = player.modulate
	player.modulate = Color(2, 2, 0, 1) # Turns the whole bot Gold
	await get_tree().create_timer(invincible_duration).timeout
	player.is_invincible = false
	player.modulate = original_modulate

# --- PURGE (SCREEN WIPE) ---
func cast_purge() -> void:
	if purge_scene:
		var purge_vfx = purge_scene.instantiate()
		get_tree().root.add_child(purge_vfx) 
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(purge_damage)

# --- SIGKILL (METEORS) ---
func cast_meteor() -> void:
	audio.play_sfx("sigkill")
	for i in range(3):
		fire_one_meteor()
		await get_tree().create_timer(0.2).timeout

func fire_one_meteor() -> void:
	if not explosion_scene: return
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	if all_enemies.is_empty(): return
		
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
	player.apply_shake(player.meteor_shake_intensity)
	
	var hit_enemies = get_tree().get_nodes_in_group("enemy")
	for e in hit_enemies:
		if e.global_position.distance_to(boom.global_position) < meteor_impact_radius:
			if e.has_method("take_damage"):
				e.take_damage(meteor_damage)

# --- DEFRAG (PIERCING STAR) ---
func cast_defrag() -> void:
	if not defrag_scene: return
	
	audio.play_sfx("defrag") 
	
	var defrag = defrag_scene.instantiate()
	get_tree().current_scene.add_child(defrag)
	
	defrag.global_position = global_position
	
	# --- NEW: MOBILE AUTO-AIM LOGIC ---
	var target = player.get_nearest_enemy()
	
	if target:
		# Lock onto the closest enemy
		defrag.direction = (target.global_position - global_position).normalized()
	else:
		# Fallback: Fire straight ahead if the screen is empty
		defrag.direction = player.last_facing_direction 
		
	defrag.damage = defrag_damage
