extends Control

func _ready() -> void:
	# 1. Hide the menu when the game starts
	visible = false
	# 2. Connect to the global signal
	# This says: "When GameManager shouts, run my 'show_options' function"
	GameManager.level_up_triggered.connect(show_options)

# This function will be called by the GameManager later
func show_options() -> void:
	visible = true
	get_tree().paused = true # FREEZE THE GAME

func _on_btn_speed_pressed() -> void:
	print("Speed Selected")
	# We will add the actual upgrade logic in the next step
	close_menu()

func _on_btn_cooldown_pressed() -> void:
	print("Cooldown Selected")
	close_menu()

func _on_btn_damage_pressed() -> void:
	print("Damage Selected")
	close_menu()

func close_menu() -> void:
	visible = false
	get_tree().paused = false # RESUME THE GAME
