extends Node

# Global Variables
var time_elapsed: float = 0.0
var kills: int = 0

func _process(delta: float) -> void:
	# Count up every frame
	time_elapsed += delta

func reset() -> void:
	# We will call this when restarting the game
	time_elapsed = 0.0
	kills = 0
