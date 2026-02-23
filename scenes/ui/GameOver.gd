extends CanvasLayer

@onready var audio = AudioManager

# --- UI REFERENCES ---
# Adjust these paths if your hierarchy changes!
@onready var run_stats_label: Label = $CenterContainer/VBoxContainer/RunStatsLabel
@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel
@onready var total_label: Label = $CenterContainer/VBoxContainer/TotalLabel
@onready var reboot_button: Button = $CenterContainer/VBoxContainer/Button

func _ready() -> void:
	# 1. Start Hidden
	visible = false 
	GameManager.game_over_triggered.connect(_on_game_over_triggered)
	
	# 3. Connect Button (Safety check)
	if not reboot_button.pressed.is_connected(_on_button_pressed):
		reboot_button.pressed.connect(_on_button_pressed)

# Call this function when the Player emits the 'died' signal
# OR call this from Player.gd: get_tree().root.get_node("Main/GameOver")._on_player_died()
func _on_game_over_triggered() -> void:
	print("GAME OVER SCREEN ACTIVATED")
	audio.stop_all_loops(true)
	# 1. UPDATE STATS
	# We pull the specific numbers from our Managers
	if run_stats_label:
		run_stats_label.text = "Targets Neutralized: " + str(GameManager.kills)
		
	if gold_label:
		gold_label.text = "Bounty Collected: " + str(GameManager.gold_current_run)
		
	if total_label:
		# GameData should have been saved/updated by Player.die() just before this
		var true_total = GameData.gold + GameManager.gold_current_run
		total_label.text = "Net Worth: " + GameData.format_number(true_total)
	# audio.start_loop("game_over")
	visible = true
	get_tree().paused = true

func _on_button_pressed() -> void:
	# 1. Helper stops the clock, unpauses, and changes scene
	# audio.stop_loop("game_over")
	GameManager.game_reset()
	GameManager.return_to_main_menu()
	
	# 2. Since this screen was added to 'root' (outside the scene), 
	# we must destroy it manually so it doesn't get stuck on top of the menu.
	queue_free()
