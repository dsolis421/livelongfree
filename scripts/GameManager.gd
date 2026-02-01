extends Node
signal xp_updated(current: int, target: int)
signal level_up_triggered

# --- CONFIGURATION (Change these to tune the game) ---
const STARTING_LEVEL = 6 # TODO Reset this to 1 after testing
const STARTING_XP = 0
const STARTING_TARGET_XP = 50 # Set this to 30, 50, 100... whatever you want the first level to be.

# Global Variables
var time_elapsed: float = 0.0
var kills: int = 0
var level: int = STARTING_LEVEL
var experience: int = STARTING_XP
var target_experience: int = STARTING_TARGET_XP

func _ready() -> void:
	reset()

func _process(delta: float) -> void:
	# Count up every frame
	time_elapsed += delta

func reset() -> void:
	# We will call this when restarting the game
	time_elapsed = 0.0
	kills = 0
	level = STARTING_LEVEL
	experience = STARTING_XP
	target_experience = STARTING_TARGET_XP
	
	# Reset the UI immediately so it doesn't show old numbers
	xp_updated.emit(experience, target_experience)

# --- NEW FUNCTION ---
func add_experience(amount: int) -> void:
	experience += amount
	print("XP Gained! Total: ", experience, " / ", target_experience)
	
	# Check for Level Up
	if experience >= target_experience:
		level_up()
		
	xp_updated.emit(experience, target_experience)

func level_up() -> void:
	experience -= target_experience
	clear_screen_for_levelup()
	level += 1
	
	# Increase difficulty (Next level requires 50% more XP)
	target_experience = int(target_experience * 1.25)
	level_up_triggered.emit()
	xp_updated.emit(experience, target_experience)
	print("LEVEL UP!!! Now Level: ", level)
	print("Next Level requires: ", target_experience)
	
func clear_screen_for_levelup() -> void:
	print("--- LEVEL UP WIPE INITIATED ---")
	
	# 1. Delete all Enemies
	get_tree().call_group("enemy", "queue_free")
	
	# 2. Delete all Loot (Gems, Pickups)
	# Make sure your Gem.tscn and ItemPickup.tscn are in the "loot" group!
	get_tree().call_group("loot", "queue_free")
	
	# 3. Delete all Projectiles (Clean slate)
	get_tree().call_group("projectile", "queue_free")
	
