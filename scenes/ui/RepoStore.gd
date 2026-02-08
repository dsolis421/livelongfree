extends CanvasLayer

@onready var bank_label: Label = $MarginContainer/VBoxContainer/BankLabel
@onready var return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

func _ready() -> void:
	add_to_group("store_ui") # Allows rows to tell me to update
	update_gold_display()
	
	return_button.pressed.connect(_on_return_pressed)

func update_gold_display() -> void:
	bank_label.text = "BANK: " + str(GameData.gold) + " G"

func _on_return_pressed() -> void:
	# Save just in case
	GameData.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
