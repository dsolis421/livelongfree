extends Node

@onready var audio = AudioManager

# --- SIGNALS ---
signal xp_updated(current: int, target: int)
signal level_up_triggered(level: int)
signal boss_spawn_requested
signal boss_incoming_warning
signal boss_health_initialized(max_hp: int)
signal boss_health_changed(new_hp: int)
signal boss_cleared_ui
signal boss_supernova_flash
signal extraction_requested
signal game_over_triggered

# --- CONFIGURATION ---
const STARTING_XP = 0
const STARTING_TARGET_XP = 150
const STAGE_TIME_LIMIT: float = 60.0

# --- SESSION DATA ---
var kills: int = 0
var gold_current_run: int = 0
var sectors_current_run: int = 0
var experience: int = STARTING_XP
var target_experience: int = STARTING_TARGET_XP
var level: int = 1
# var current_sector: int = 1
var achievement_popup: Node = null

# --- RUN MODIFIERS (SCALING) ---
var run_enemy_hp_mult: float = 1.0
# var run_enemy_dmg_bonus: int = 0
var run_spawn_timer_mod: float = 0.0
var run_max_time_bonus: float = 0.0
var run_enemy_speed_mod: int = 0
var run_xp_level_mult: float = 1.0

# --- INTERNAL FLAGS ---
var needs_full_reset: bool = true
var is_run_active: bool = false

# --- STAGE DATA ---
var time_elapsed: float = 0.0
var time_remaining: float = STAGE_TIME_LIMIT
var boss_has_spawned: bool = false
var is_boss_active: bool = false
var is_game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_run_active or is_game_over or get_tree().paused:
		return

	time_remaining -= delta
	time_elapsed += delta

	if time_remaining <= 0 and not boss_has_spawned:
		time_remaining = 0.0
		spawn_final_boss()

# --- 1. CALLED BY MAIN MENU ("New Game") ---
func start_new_game_from_menu() -> void:
	if is_run_active:
		print("Resuming active run")
		needs_full_reset = false
	else:
		print("Starting new run")
		needs_full_reset = true
		is_run_active = true
	calculate_difficulty()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- 2. CALLED BY VICTORY SCREEN ("Next Sector") ---
func continue_to_next_sector() -> void:
	# needs_full_reset = false
	calculate_difficulty()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- 3. CALLED BY MAIN.GD (When Drone Lands) ---
func start_mission_logic() -> void:
	print("--- STARTING MISSION LOGIC ---")
	# check_achievements()
	# A. Handle the "New Game" vs "Next Level" decision here
	print(" > Continuing Career (Kills: ", kills, ")")
	# B. ALWAYS Reset Stage Logic (Fixes Extraction/Boss bugs)
	time_remaining = STAGE_TIME_LIMIT + run_max_time_bonus
	boss_has_spawned = false
	is_boss_active = false
	is_game_over = false # <--- CRITICAL: Allows extraction to happen again

	# C. Update UI
	xp_updated.emit(experience, target_experience)

# --- GAMEPLAY LOGIC ---
func add_kill() -> void:
	if is_game_over: return
	kills += 1

func add_experience(amount: int) -> void:
	if is_game_over: return
	experience += amount
	if experience >= target_experience:
		level_up()
		get_tree().create_timer(0.1).timeout.connect(func():
			audio.play_sfx("level_up")
		)
	xp_updated.emit(experience, target_experience)

func level_up() -> void:
	experience -= target_experience
	if experience < 0: experience = 0
	level += 1
	target_experience = int((target_experience * 1.2) * run_xp_level_mult)
	print("UPGRADE READY! Tier: ", level)
	level_up_triggered.emit(level)
	xp_updated.emit(experience, target_experience)

# --- BOSS & ENDING LOGIC ---
func spawn_final_boss() -> void:
	print("Spawn Final Boss")
	boss_has_spawned = true
	is_boss_active = true
	audio.start_loop("boss_loop")
	boss_incoming_warning.emit()
	boss_spawn_requested.emit()

func on_boss_died() -> void:
	is_boss_active = false
	audio.stop_loop("boss_loop")
	boss_cleared_ui.emit()
	start_extraction_sequence()

func start_extraction_sequence() -> void:
	# Ensure we don't trigger this twice
	if is_game_over: return
	
	is_game_over = true # Stop the clock/spawning
	
	get_tree().call_group("enemy", "queue_free")
	get_tree().call_group("projectile", "queue_free")
	
	extraction_requested.emit()

func on_extraction_complete() -> void:
	print("VICTORY! Loading Win Screen...")
	audio.stop_loop("agent_drone", true)
	sectors_current_run += 1
	var win_screen = load("res://scenes/ui/VictoryScreen.tscn").instantiate()
	await get_tree().create_timer(0.5).timeout
	get_tree().root.add_child(win_screen)
	get_tree().paused = true

# --- HELPERS ---
func report_boss_spawn(max_hp: int) -> void:
	boss_health_initialized.emit(max_hp)

func report_boss_damage(current_hp: int) -> void:
	boss_health_changed.emit(current_hp)

func trigger_supernova() -> void:
	boss_supernova_flash.emit()

func add_gold(amount: int) -> void:
	gold_current_run += amount

# --- SAVE SYSTEM ---
func save_game() -> void:
	if gold_current_run > 0:
		GameData.add_gold(gold_current_run)
		gold_current_run = 0

	if kills > GameData.high_kills:
		GameData.high_kills = kills
		
	if sectors_current_run > GameData.max_sectors:
		GameData.max_sectors = sectors_current_run
		
	GameData.save_game()
	
# --- PLAYER DEATH & MENU LOGIC ---

# 1. STOP THE CLOCK (Call this from Player.gd -> die())
func on_player_died() -> void:
	print("--- PLAYER DIED: STOPPING CLOCK ---")
	# This flag stops the _process loop immediately so the timer freezes
	is_game_over = true
	is_run_active = false
	game_over_triggered.emit()

# 2. SAFE RETURN (Call this from GameOverScreen or VictoryScreen buttons)
func return_to_main_menu() -> void:
	# Double check the flag is set so the timer is dead
	is_game_over = true 
	# IMPORTANT: Unpause the tree, or the Main Menu will be frozen!
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func calculate_difficulty() -> void:
	# 1. BUFFER -> TIME (+15s per level)
	var buffer_lvl = GameData.get_upgrade_level("buffer")
	run_max_time_bonus = buffer_lvl * 15.0 
	
	# 2. DAMAGE -> SPAWN RATE (-0.1s per level)
	var dmg_lvl = GameData.get_upgrade_level("damage")
	run_spawn_timer_mod = dmg_lvl * 0.12
	
	# 3. RICOCHET -> ENEMY SPEED 
	# +5 Enemy Movement Per Ric Level
	var ric_lvl = GameData.get_upgrade_level("ricochet")
	run_enemy_speed_mod = (ric_lvl * 30) + (sectors_current_run * 2)
	
	# 4. SIPHON -> XP LEVEL (+10% per level)
	var xp_lvl = GameData.get_upgrade_level("magnet")
	run_xp_level_mult = 1 + (xp_lvl * .01)
	
	# 5. SLOTS -> ENEMY HP (+1 per 2 levels)
	# 2x HP for every 2 slots opened.
	var slot_lvl = GameData.get_upgrade_level("slots")
	run_enemy_hp_mult = int(1.0 + slot_lvl + sectors_current_run)

	print("--- SECTOR DIFFICULTY ---")
	print("Time Add: +", run_max_time_bonus)
	print("Spawn Mod: -", run_spawn_timer_mod)
	print("Elite HP: x", run_enemy_hp_mult)
	print("Speed Mod: +", run_enemy_speed_mod)
	print("XP Mod: x", run_xp_level_mult)

func check_achievements() -> void:
	# 1. CHECK: Clear 10 Sectors
	# Using 'level' variable (assuming level 1 = Sector 1)
	if sectors_current_run >= 1:
		unlock_achievement("sector_10")

	# 2. CHECK: Max Damage
	if is_upgrade_maxed("damage"):
		unlock_achievement("max_damage")

	# 3. CHECK: Max Siphon
	if is_upgrade_maxed("magnet"):
		unlock_achievement("max_siphon")
		
	# 4. CHECK: Max Ricochet
	if is_upgrade_maxed("ricochet"):
		unlock_achievement("max_ricochet")
		
	# 5. CHECK: Max Slots
	if is_upgrade_maxed("slots"): # Assuming 3 is max
		unlock_achievement("max_slots")
		
	# 6. CHECK: Max Buffer
	if is_upgrade_maxed("buffer"):
		unlock_achievement("max_buffer")

func is_upgrade_maxed(key: String) -> bool:
	if not GameData.UPGRADE_CONFIG.has(key): return false
	
	var current_lvl = GameData.get_upgrade_level(key)
	var max_lvl = GameData.UPGRADE_CONFIG[key].max_level
	
	return current_lvl >= max_lvl
	
func unlock_achievement(key: String) -> void:
	# 1. If we already have it, stop.
	if key in GameData.unlocked_achievements:
		return
	# 2. Unlock it
	print("Unlock achievement: " + key)
	GameData.unlocked_achievements.append(key)
	GameData.save_game() # Save immediately so they don't lose it if they crash
	
	# 3. Show UI Notification (We will build this next)
	show_achievement_popup(key)

func show_achievement_popup(key: String):
	if achievement_popup:
		achievement_popup.show_medal(key)
		audio.play_sfx("new_medal")
	else:
		print(" > POPUP ERROR")
		
func game_reset() -> void:
		print(" > Performing Full Career Reset")
		kills = 0
		level = 1
		experience = STARTING_XP
		target_experience = int(STARTING_TARGET_XP * run_xp_level_mult)
		gold_current_run = 0
		sectors_current_run = 0
		is_run_active = false
		needs_full_reset = false # Done!
