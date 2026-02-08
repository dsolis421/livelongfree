extends Node

# --- SIGNALS ---
signal xp_updated(current: int, target: int)
signal level_up_triggered(level) 
signal boss_spawn_requested 
signal boss_incoming_warning 
signal boss_health_initialized(max_hp: int)
signal boss_health_changed(new_hp: int)
signal boss_cleared_ui
signal boss_supernova_flash
signal extraction_requested 

# --- CONFIGURATION ---
const STARTING_LEVEL = 1
const STARTING_XP = 0
const STARTING_TARGET_XP = 10 
const STAGE_TIME_LIMIT: float = 60.0 

# --- GLOBAL VARIABLES (Current Run) ---
var time_elapsed: float = 0.0
var time_remaining: float = STAGE_TIME_LIMIT
var kills: int = 0
var level: int = STARTING_LEVEL
var experience: int = STARTING_XP
var target_experience: int = STARTING_TARGET_XP

# --- FIXED VARIABLES ---
var gold_current_run: int = 0 

# --- STATE FLAGS ---
var boss_has_spawned: bool = false 
var is_boss_active: bool = false
var is_game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS 
	# Initialize with a hard reset to be safe
	start_new_run()

func _process(delta: float) -> void:
	if is_game_over or get_tree().paused: return
	
	time_remaining -= delta
	time_elapsed += delta # Track total time for records
	
	if time_remaining <= 0 and not boss_has_spawned:
		time_remaining = 0.0 
		spawn_final_boss()

# --- STATE MANAGEMENT (THE NEW LOGIC) ---

# 1. HARD RESET: Called from MainMenu or GameOver
# Wipes EVERYTHING. Starting fresh.
func start_new_run() -> void:
	print("--- STARTING NEW RUN ---")
	kills = 0
	level = STARTING_LEVEL
	experience = STARTING_XP
	target_experience = STARTING_TARGET_XP
	gold_current_run = 0
	
	_reset_stage_state()

# 2. SOFT RESET: Called from VictoryScreen -> Next Sector
# Keeps Kills, Gold, Level, XP. Resets Time and Flags.
func advance_to_next_sector() -> void:
	print("--- ADVANCING TO NEXT SECTOR ---")
	# We intentionally do NOT reset kills, level, or gold here.
	_reset_stage_state()

# 3. HELPER: Resets only the Stage/Scene specific stuff
func _reset_stage_state() -> void:
	time_remaining = STAGE_TIME_LIMIT 
	boss_has_spawned = false
	is_boss_active = false
	is_game_over = false
	
	# Emit update so HUD fixes the XP bar instantly
	xp_updated.emit(experience, target_experience)

# --- 1. XP LOGIC ---
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
	print("LEVEL UP! New Level: ", level)
	level_up_triggered.emit(level)
	xp_updated.emit(experience, target_experience)

# --- 2. BOSS LOGIC ---
func spawn_final_boss() -> void:
	print("!!! TIME LIMIT REACHED - SUMMONING BOSS !!!")
	boss_has_spawned = true
	is_boss_active = true
	boss_incoming_warning.emit()
	boss_spawn_requested.emit()

# --- 3. VICTORY/DEATH LOGIC ---
func on_boss_died() -> void:
	print("!!! BOSS DEFEATED - INITIATING EXTRACTION !!!")
	is_boss_active = false
	boss_cleared_ui.emit()
	start_extraction_sequence()

func start_extraction_sequence() -> void:
	if is_game_over: return
	is_game_over = true
	
	get_tree().call_group("enemy", "queue_free")
	get_tree().call_group("projectile", "queue_free")
	
	# IMPORTANT CHANGE: 
	# We removed save_game() from here.
	# We only save when the player actually leaves the run (Return to Base or Death).
	
	extraction_requested.emit()

func on_extraction_complete() -> void:
	print("VICTORY! Loading Win Screen...")
	var win_screen = load("res://scenes/ui/VictoryScreen.tscn").instantiate()
	get_tree().root.add_child(win_screen)
	get_tree().paused = true

# --- UI / HELPERS ---
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
	print("Saving Run Progress...")

	# 1. Deposit Gold into the Bank
	if gold_current_run > 0:
		GameData.add_gold(gold_current_run)
		print("Deposited ", gold_current_run, " gold.")
		
		# CRITICAL: We clear the 'run' gold so we don't double-deposit 
		# if this function gets called twice by accident.
		gold_current_run = 0 

	# 2. Update High Kills
	if kills > GameData.high_kills:
		GameData.high_kills = kills
		print("New Kill Record: ", kills)

	# 3. Save to Disk
	GameData.save_game()
