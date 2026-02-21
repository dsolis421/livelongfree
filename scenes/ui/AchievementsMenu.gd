extends Control

# Preload the slot template
const SLOT_SCENE = preload("res://scenes/ui/AchievementSlot.tscn")

@onready var grid = $ScrollContainer/GridContainer

func _ready() -> void:
	populate_grid()

func populate_grid():
	# 1. Clear any placeholder children
	for child in grid.get_children():
		child.queue_free()
		
	# 2. Loop through EVERY achievement defined in GameData
	for key in GameData.ACHIEVEMENT_DATA:
		var data = GameData.ACHIEVEMENT_DATA[key]
		
		# 3. Check if player has it
		var unlocked = key in GameData.unlocked_achievements
		
		# 4. Create the Slot
		var slot = SLOT_SCENE.instantiate()
		grid.add_child(slot)
		
		# 5. Fill it with data
		slot.set_medal_data(key, data, unlocked)

func _on_back_to_repo_pressed() -> void:
	# Return to Main Menu
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
