extends Control

# References to our Stat Labels
@onready var level_label = $MainLayout/RightColumn/StatsPanel/VBoxContainer/LevelLabel
@onready var kills_label = $MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel
@onready var time_label = $MainLayout/RightColumn/StatsPanel/VBoxContainer/TimeLabel

func _ready() -> void:
	# 1. Load the data from GameManager
	var data = GameManager.save_data
	
	# 2. Update Text
	level_label.text = "Peak Level: " + str(data["high_level"])
	kills_label.text = "Peak Kills: " + str(data["high_kills"])
	
	# Format time (Seconds -> MM:SS)
	var time = data["best_time"]
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	time_label.text = "Best Time: %02d:%02d" % [minutes, seconds]
	
	# 3. Connect Play Button
	var play_btn = $MainLayout/RightColumn/PlayButton
	play_btn.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	# RESET the Game Session State
	# (Crucial: otherwise you start level 1 with level 5 stats!)
	# GameManager.score = 0
	GameManager.level = GameManager.STARTING_LEVEL
	GameManager.experience = GameManager.STARTING_XP
	GameManager.time_elapsed = 0.0
	GameManager.kills = 0
	GameManager.is_boss_active = false
	GameManager.pending_level_up = false
	
	# Launch Game
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
