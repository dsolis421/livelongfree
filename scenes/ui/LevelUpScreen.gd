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
	apply_to_player("movement_speed")
	print("Speed Selected")

func _on_btn_cooldown_pressed() -> void:
	apply_to_player("cooldown")
	print("Cooldown Selected")

func close_menu() -> void:
	visible = false
	get_tree().paused = false # RESUME THE GAME
	
func apply_to_player(type: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.apply_upgrade(type)

	close_menu()
