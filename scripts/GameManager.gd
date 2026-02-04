extends Node

signal xp_updated(current: int, target: int)
signal level_up_triggered
signal boss_spawn_requested # NEW: Tells the Spawner to do its job

# --- CONFIGURATION ---
const STARTING_LEVEL = 5 
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

func _ready() -> void:
	reset()

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
	is_boss_active = true
	pending_level_up = true # We owe them a level!
	
	# Tell the Spawner (and UI) to bring out the big guy
	boss_spawn_requested.emit()

# This function is called by Boss.gd when it dies
func on_boss_died() -> void:
	print("!!! BOSS DEFEATED - RESUMING PROGRESS !!!")
	print("Pending Level Up Status: ", pending_level_up)
	is_boss_active = false
	
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
