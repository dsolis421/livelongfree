extends Node

signal xp_updated(current: int, target: int)
signal level_up_triggered
signal boss_spawn_requested # Tells the Spawner to do its job
signal boss_incoming_warning # Triggers the flashing text
signal boss_health_initialized(max_hp: int) # Shows the bar
signal boss_health_changed(new_hp: int) # Updates the bar
signal boss_cleared_ui # Hides the bar
signal boss_supernova_flash

# --- CONFIGURATION ---
const STARTING_LEVEL = 6
const STARTING_XP = 0
const STARTING_TARGET_XP = 50

# Global Variables
var time_elapsed: float = 0.0
var kills: int = 0
var level: int = STARTING_LEVEL
var experience: int = STARTING_XP
var target_experience: int = STARTING_TARGET_XP

# --- STATE FLAGS ---
var is_boss_active: bool = false
var pending_level_up: bool = false # NEW: Remembers we owe the player a level up
# --- SAVE SYSTEM SETTINGS ---
var save_path: String = "user://savegame.json"

# Default Records (Will be overwritten if a save file exists)
var save_data: Dictionary = {
	"high_level": 1,
	"high_kills": 0,
	"best_time": 0.0
}
func _ready() -> void:
	reset()
	load_game()

func _process(delta: float) -> void:
	time_elapsed += delta

func reset() -> void:
	time_elapsed = 0.0
	kills = 0
	level = STARTING_LEVEL
	experience = STARTING_XP
	target_experience = STARTING_TARGET_XP
	
	is_boss_active = false
	pending_level_up = false
	
	xp_updated.emit(experience, target_experience)

func add_experience(amount: int) -> void:
	# If boss is active, we can either CAP the XP or let it overflow.
	# Let's let it overflow (save it for next level), but NOT trigger level up yet.
	experience += amount
	
	# Check if we hit the target
	if experience >= target_experience:
		
		print("---XP THRESHOLD REACHED---")
		print("Current Level: ", level)
		print("Is Multiple of 5? ", level % 5 == 0)
		print("Is Boss Active? ", is_boss_active)
		print("Is Pending Level Up? ", pending_level_up)
		
		# --- INTERCEPT LOGIC ---
		# If we are at Level 5, 10, 15... AND we aren't already fighting a boss
		if level % 5 == 0 and not is_boss_active and not pending_level_up:
			print(">>> Condition Met: BOSS FIGHT!")
			call_deferred("trigger_boss_fight")
		elif is_boss_active:
			print(">>> Skipping: Boss is already active")
			# We already triggered it, just wait.
			# We mark 'pending' so we know to level up immediately after boss dies.
			pending_level_up = true
		else:
			# Normal Level Up (Levels 1, 2, 3, 4, 6, 7...)
			print(">>> CONDITIONS FAILED: Normal Level Up")
			level_up()
		
	xp_updated.emit(experience, target_experience)

func trigger_boss_fight() -> void:
	print("!!! BOSS GATE REACHED - LEVEL UP PAUSED !!!")
	boss_incoming_warning.emit()
	is_boss_active = true
	pending_level_up = true
	boss_spawn_requested.emit()

# This function is called by Boss.gd when it dies
func on_boss_died() -> void:
	print("!!! BOSS DEFEATED - RESUMING PROGRESS !!!")
	print("Pending Level Up Status: ", pending_level_up)
	is_boss_active = false
	
	boss_cleared_ui.emit()
	
	# Pay the debt: Give the Level Up we withheld
	if pending_level_up:
		print(">>> PAYING THE DEBT: TRIGGERING LEVEL UP NOW <<<")
		level_up()
		pending_level_up = false
	else:
		print(">>>ERROR: No pending level up found?")

func level_up() -> void:
	# Standard Logic
	experience -= target_experience
	
	# Safety check: If they had SO much XP they leveled up twice, keep the remainder
	if experience < 0: experience = 0
	
	clear_screen_for_levelup()
	level += 1
	
	target_experience = int(target_experience * 1.25)
	level_up_triggered.emit()
	xp_updated.emit(experience, target_experience)
	print("LEVEL UP!!! Now Level: ", level)
	
func clear_screen_for_levelup() -> void:
	# Only wipe screen if it's a real level up, not the start of a boss fight
	get_tree().call_group("enemy", "queue_free")
	get_tree().call_group("loot", "queue_free")
	get_tree().call_group("projectile", "queue_free")

func report_boss_spawn(max_hp: int) -> void:
	boss_health_initialized.emit(max_hp)
	
func report_boss_damage(current_hp: int) -> void:
	boss_health_changed.emit(current_hp)

func trigger_supernova() -> void:
	boss_supernova_flash.emit()

func check_and_save_records(current_level: int, current_kills: int, current_time: float) -> void:
	print("Checking for new records...")
	var dirty = false # "Dirty" means data changed and needs saving
	
	# 1. Check Level
	if current_level > save_data["high_level"]:
		print("NEW RECORD: Level ", current_level)
		save_data["high_level"] = current_level
		dirty = true
		
	# 2. Check Kills
	if current_kills > save_data["high_kills"]:
		print("NEW RECORD: Kills ", current_kills)
		save_data["high_kills"] = current_kills
		dirty = true
		
	# 3. Check Time
	if current_time > save_data["best_time"]:
		print("NEW RECORD: Time ", current_time)
		save_data["best_time"] = current_time
		dirty = true
		
	# 4. Save to Disk if anything changed
	if dirty:
		save_game()
	else:
		print("No new records set.")

func save_game() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		print("Game Saved Successfully: ", save_data)

func load_game() -> void:
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		
		if parse_result == OK:
			var loaded_data = json.get_data()
			# Safety Merging: Only update keys that actually exist
			if "high_level" in loaded_data: save_data["high_level"] = int(loaded_data["high_level"])
			if "high_kills" in loaded_data: save_data["high_kills"] = int(loaded_data["high_kills"])
			if "best_time" in loaded_data: save_data["best_time"] = float(loaded_data["best_time"])
			print("Game Loaded: ", save_data)
		else:
			print("JSON Parse Error. Starting with default records.")
	else:
		print("No save file found. Starting fresh.")
