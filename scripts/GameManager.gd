extends Node

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

# --- CONFIGURATION ---
const STARTING_XP = 0
const STARTING_TARGET_XP = 10
const STAGE_TIME_LIMIT: float = 10.0

# --- SESSION DATA ---
var kills: int = 0          # Your Score
var gold_current_run: int = 0
var experience: int = STARTING_XP
var target_experience: int = STARTING_TARGET_XP
var level: int = 1

# --- INTERNAL FLAGS ---
var needs_full_reset: bool = true # <--- THE MAGIC FIX

# --- STAGE DATA ---
var time_elapsed: float = 0.0
var time_remaining: float = STAGE_TIME_LIMIT
var boss_has_spawned: bool = false
var is_boss_active: bool = false
var is_game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_game_over or get_tree().paused: return

	time_remaining -= delta
	time_elapsed += delta

	if time_remaining <= 0 and not boss_has_spawned:
		time_remaining = 0.0
		spawn_final_boss()

# --- 1. CALLED BY MAIN MENU ("New Game") ---
func start_new_game_from_menu() -> void:
	needs_full_reset = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- 2. CALLED BY VICTORY SCREEN ("Next Sector") ---
func continue_to_next_sector() -> void:
	needs_full_reset = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- 3. CALLED BY MAIN.GD (When Drone Lands) ---
func start_mission_logic() -> void:
	print("--- STARTING MISSION LOGIC ---")
	
	# A. Handle the "New Game" vs "Next Level" decision here
	if needs_full_reset:
		print(" > Performing Full Career Reset")
		kills = 0
		level = 1
		experience = STARTING_XP
		target_experience = STARTING_TARGET_XP
		gold_current_run = 0
		needs_full_reset = false # Done!
	else:
		print(" > Continuing Career (Kills: ", kills, ")")

	# B. ALWAYS Reset Stage Logic (Fixes Extraction/Boss bugs)
	time_remaining = STAGE_TIME_LIMIT
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
	xp_updated.emit(experience, target_experience)

func level_up() -> void:
	experience -= target_experience
	if experience < 0: experience = 0
	level += 1
	target_experience = int(target_experience * 1.2)
	print("UPGRADE READY! Tier: ", level)
	level_up_triggered.emit(level)
	xp_updated.emit(experience, target_experience)

# --- BOSS & ENDING LOGIC ---
func spawn_final_boss() -> void:
	print("!!! TIME LIMIT REACHED - SUMMONING BOSS !!!")
	boss_has_spawned = true
	is_boss_active = true
	boss_incoming_warning.emit()
	boss_spawn_requested.emit()

func on_boss_died() -> void:
	print("!!! BOSS DEFEATED - SECTOR CLEARED !!!")
	is_boss_active = false
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
	var win_screen = load("res://scenes/ui/VictoryScreen.tscn").instantiate()
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

	GameData.save_game()
	
# --- PLAYER DEATH & MENU LOGIC ---

# 1. STOP THE CLOCK (Call this from Player.gd -> die())
func on_player_died() -> void:
	print("--- PLAYER DIED: STOPPING CLOCK ---")
	# This flag stops the _process loop immediately so the timer freezes
	is_game_over = true 

# 2. SAFE RETURN (Call this from GameOverScreen or VictoryScreen buttons)
func return_to_main_menu() -> void:
	print("--- RETURNING TO MENU ---")
	
	# Double check the flag is set so the timer is dead
	is_game_over = true 
	
	# IMPORTANT: Unpause the tree, or the Main Menu will be frozen!
	get_tree().paused = false 
	
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
