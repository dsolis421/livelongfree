extends Control

# References to our Stat Labels
@onready var kills_label = $MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel
@onready var repo_button = $MainLayout/RightColumn/RepoButton
@onready var audio = AudioManager

func _ready() -> void:
	# 1. Update Labels directly from GameData (The new source of truth)
	GameData.load_game()
	audio.play_music("main_menu")
	# Display Gold
	if has_node("MainLayout/RightColumn/StatsPanel/VBoxContainer/GoldLabel"):
		$MainLayout/RightColumn/StatsPanel/VBoxContainer/GoldLabel.text = "Net Worth: " + GameData.format_number(GameData.gold)
	
	if has_node("MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel"):
		$MainLayout/RightColumn/StatsPanel/VBoxContainer/KillsLabel.text = "Most Kills: " + str(GameData.high_kills)

	if has_node("MainLayout/RightColumn/StatsPanel/VBoxContainer/SectorsLabel"):
		$MainLayout/RightColumn/StatsPanel/VBoxContainer/SectorsLabel.text = "Max Sectors: " + str(GameData.max_sectors)
		
	# 3. Connect Play Button
	var play_btn = $MainLayout/RightColumn/PlayButton
	if not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.pressed.connect(_on_play_pressed)
	
	repo_button.pressed.connect(_on_repo_pressed)


func _on_play_pressed() -> void:
	audio.stop_music()
	GameManager.start_new_game_from_menu()
	

func _on_repo_pressed():
	# Go to the Store Scene
	get_tree().change_scene_to_file("res://scenes/ui/RepoStore.tscn")
	
func _on_medals_button_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/AchievementsMenu.tscn")
