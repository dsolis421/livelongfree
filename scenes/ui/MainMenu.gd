extends Control

# References to our Stat Labels
@onready var kills_label = $MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel

func _ready() -> void:
	# 1. Update Labels directly from GameData (The new source of truth)
	GameData.load_game()
	print("DEBUG: Loaded Gold: ", GameData.gold)
	print("DEBUG: Loaded Kills: ", GameData.high_kills)
	# Display Gold
	if has_node("MainLayout/RightColumn/StatsPanel/VBoxContainer/GoldLabel"):
		$MainLayout/RightColumn/StatsPanel/VBoxContainer/GoldLabel.text = "Net Worth: " + str(GameData.gold)
	
	# Display High Kills (Your new Score)
	# Assuming you have a label named 'KillsLabel' or similar
	if has_node("MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel"):
		$MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel.text = "Most Kills: " + str(GameData.high_kills)

	# 3. Connect Play Button
	var play_btn = $MainLayout/RightColumn/PlayButton
	if not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	# 1. DELEGATE CLEANUP
	# Use the new function name!
	# This ensures we start at Level 1 with 0 Gold and 0 XP.
	GameManager.start_new_run()
	
	# 2. Launch Game
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
