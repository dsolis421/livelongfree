extends Node

# Global Variables
var time_elapsed: float = 0.0
var kills: int = 0

# --- NEW RPG STATS ---
var experience: int = 0
var level: int = 1
var target_experience: int = 100 # How much XP to reach Level 2

func _process(delta: float) -> void:
	# Count up every frame
	time_elapsed += delta

func reset() -> void:
	# We will call this when restarting the game
	time_elapsed = 0.0
	kills = 0
	experience = 0
	level = 1
	target_experience = 100

# --- NEW FUNCTION ---
func add_experience(amount: int) -> void:
	experience += amount
	print("XP Gained! Total: ", experience, " / ", target_experience)
	
	# Check for Level Up
	if experience >= target_experience:
		level_up()

func level_up() -> void:
	# 1. Carry over extra XP (e.g. if you have 105/100, you keep 5)
	experience -= target_experience
	
	# 2. Increase Level
	level += 1
	
	# 3. Increase difficulty (Next level requires 50% more XP)
	target_experience = int(target_experience * 1.5)
	
	print("LEVEL UP!!! Now Level: ", level)
	print("Next Level requires: ", target_experience)
