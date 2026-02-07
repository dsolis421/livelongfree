extends Node

# --- SIGNALS ---
signal xp_updated(current: int, target: int)
signal level_up_triggered(level) # Triggers Upgrade Menu
signal boss_spawn_requested # Tells Spawner to spawn the Boss
signal boss_incoming_warning # Triggers flashing text
signal boss_health_initialized(max_hp: int)
signal boss_health_changed(new_hp: int)
signal boss_cleared_ui
signal boss_supernova_flash
signal extraction_requested # NEW: Tells Main.gd/Spawner to bring in the Drone

# --- CONFIGURATION ---
const STARTING_LEVEL = 1
const STARTING_XP = 0
const STARTING_TARGET_XP = 10 # Lowered for testing, adjust as needed
const STAGE_TIME_LIMIT: float = 60.0 # 5 Minutes = Boss Time

# --- GLOBAL VARIABLES ---
var time_elapsed: float = 0.0
var time_remaining: float = STAGE_TIME_LIMIT
var kills: int = 0
var level: int = STARTING_LEVEL
var experience: int = STARTING_XP
var target_experience: int = STARTING_TARGET_XP
var gold_current_run: int = 0 
var gold_total: int = 0 

# --- STATE FLAGS ---
var boss_has_spawned: bool = false # Ensures boss only spawns once
var is_boss_active: bool = false
var is_game_over: bool = false

# --- SAVE SYSTEM ---
var save_path: String = "user://savegame.json"
var save_data: Dictionary = {
	"high_level": 1, 
	"high_kills": 0, 
	"best_time": 0.0,
	"total_gold": 0
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure Manager keeps running
	reset()
	load_game()

func _process(delta: float) -> void:
	if is_game_over or get_tree().paused: return
	
	# COUNT DOWN
	time_remaining -= delta
	
	# --- THE TRIGGER ---
	# If time runs out, and we haven't spawned the boss yet...
	if time_remaining <= 0 and not boss_has_spawned:
		# Clamp to 0 so it doesn't go negative
		time_remaining = 0.0 
		spawn_final_boss()

func reset() -> void:
	time_remaining = STAGE_TIME_LIMIT # <--- Reset the clock
	kills = 0
	level = STARTING_LEVEL
	experience = STARTING_XP
	target_experience = STARTING_TARGET_XP
	
	boss_has_spawned = false
	is_game_over = false
	
	xp_updated.emit(experience, target_experience)
	gold_current_run = 0

# --- 1. XP LOGIC (Now decoupled from Bosses) ---
func add_experience(amount: int) -> void:
	if is_game_over: return
	
	experience += amount
	
	# Simple Level Up Loop
	if experience >= target_experience:
		level_up()
		
	xp_updated.emit(experience, target_experience)

func level_up() -> void:
	experience -= target_experience
	if experience < 0: experience = 0
	
	level += 1
	target_experience = int(target_experience * 1.2) # 20% Curve
	
	print("LEVEL UP! New Level: ", level)
	
	# Emit signal to open Upgrade Menu
	# Note: The Upgrade Menu should likely pause the tree when it opens
	level_up_triggered.emit(level)
	xp_updated.emit(experience, target_experience)

# --- 2. BOSS LOGIC (Controlled by Time) ---
func spawn_final_boss() -> void:
	print("!!! TIME LIMIT REACHED - SUMMONING BOSS !!!")
	boss_has_spawned = true
	is_boss_active = true
	
	# 1. Warn the Player
	boss_incoming_warning.emit()
	
	# 2. Clear the noise (Kill fodder so it's a 1v1)
	# get_tree().call_group("fodder", "queue_free")
	
	# 3. Tell Spawner to create the Boss
	boss_spawn_requested.emit()

# --- 3. VICTORY LOGIC (Triggered by Boss Death) ---
# Called by Boss.gd when hp <= 0
func on_boss_died() -> void:
	print("!!! BOSS DEFEATED - INITIATING EXTRACTION !!!")
	is_boss_active = false
	boss_cleared_ui.emit()
	start_extraction_sequence()

func start_extraction_sequence() -> void:
	if is_game_over: return
	is_game_over = true
	
	# 1. Kill remaining enemies/projectiles
	get_tree().call_group("enemy", "queue_free")
	get_tree().call_group("projectile", "queue_free")
	
	# 2. Save Data
	check_and_save_records(level, kills, time_elapsed)
	
	# 3. Signal the Main Scene to spawn the Drone
	extraction_requested.emit()

# Called by the Drone when it flies off-screen
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

# --- SAVE SYSTEM (Unchanged) ---
func check_and_save_records(current_level: int, current_kills: int, current_time: float) -> void:
	var dirty = false
	
	if not save_data.has("total_gold"): save_data["total_gold"] = 0
	if gold_current_run > 0:
		save_data["total_gold"] += gold_current_run
		gold_total = save_data["total_gold"]
		dirty = true
		
	if current_level > save_data["high_level"]:
		save_data["high_level"] = current_level
		dirty = true
	if current_kills > save_data["high_kills"]:
		save_data["high_kills"] = current_kills
		dirty = true
	if current_time > save_data["best_time"]:
		save_data["best_time"] = current_time
		dirty = true
		
	if dirty: save_game()

func save_game() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(save_data))

func load_game() -> void:
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var loaded = json.get_data()
			if "high_level" in loaded: save_data["high_level"] = int(loaded["high_level"])
			if "high_kills" in loaded: save_data["high_kills"] = int(loaded["high_kills"])
			if "best_time" in loaded: save_data["best_time"] = float(loaded["best_time"])
			if "total_gold" in loaded: save_data["total_gold"] = int(loaded["total_gold"])
			gold_total = save_data["total_gold"]
