extends Control

# References to our Stat Labels
@onready var kills_label = $MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel
@onready var repo_button = $MainLayout/RightColumn/RepoButton

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
	
	repo_button.pressed.connect(_on_repo_pressed)


func _on_play_pressed() -> void:
	GameManager.start_new_game_from_menu()

func _on_repo_pressed():
	# Go to the Store Scene
	get_tree().change_scene_to_file("res://scenes/ui/RepoStore.tscn")
