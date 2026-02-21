extends CanvasLayer

# --- UI REFERENCES ---
# We use @onready because we know the structure now.
# Make sure these node names match your Scene Tree exactly!
@onready var sectors_label: Label = $CenterContainer/VBoxContainer/SectorsLabel
@onready var run_stats_label: Label = $CenterContainer/VBoxContainer/RunStatsLabel
@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel
@onready var total_label: Label = $CenterContainer/VBoxContainer/TotalLabel
@onready var next_btn: Button = $CenterContainer/VBoxContainer/NextSector
@onready var return_btn: Button = $CenterContainer/VBoxContainer/ReturnToBase

func _ready() -> void:
	GameManager.check_achievements()
	# 1. DISPLAY STATS
	if sectors_label:
		sectors_label.text = "Sectors Cleared: " + str(GameManager.sectors_current_run)
	
	if run_stats_label:
		run_stats_label.text = "Threats Neutralized: " + str(GameManager.kills)
	
	if gold_label:
		# Use 'gold_current_run' to show what they just earned
		gold_label.text = "Bounty Collected: " + str(GameManager.gold_current_run)
		
	if total_label:
		# Use GameData to show their total bank (Persistence check!)
		var true_total = GameData.gold + GameManager.gold_current_run
		total_label.text = "Net Worth: " + str(true_total)

	# 2. CONNECT BUTTONS
	# (Your existing logic, just cleaned up with direct references)
	if next_btn:
		next_btn.pressed.connect(_on_next_mission_pressed)
	
	if return_btn:
		return_btn.pressed.connect(_on_return_pressed)
		
	# 3. MOUSE HANDLING
	# Ensure the mouse is visible so they can click buttons
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_next_mission_pressed() -> void:
	print("Loading Next Mission...")
	
	# 1. Reset Game State
	GameManager.continue_to_next_sector()
	
	# 2. IMPORTANT: Unpause!
	get_tree().paused = false
	
	# 3. Reload Main Scene (Triggers Insertion Drone)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	queue_free()
	

func _on_return_pressed() -> void:
	print("Returning to Base...")
	
	# --- THE FIX ---
	# Bank the loot now that we are leaving safely
	GameManager.save_game()
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	queue_free()
