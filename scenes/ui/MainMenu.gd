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
	# 1. DELEGATE CLEANUP
	# Instead of resetting 10 variables manually, ask the Manager to reset itself.
	# This handles level, xp, timer, kills, gold, and flags automatically.
	GameManager.reset()
	
	# 2. Launch Game
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
