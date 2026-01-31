extends Control

# We store the 'type' of item in each slot. 
# null = empty.
var slots = [null, null, null]

@onready var buttons = [$HBoxContainer/Slot1, $HBoxContainer/Slot2, $HBoxContainer/Slot3]

func _ready() -> void:
	# 1. Clear all slots visually
	update_ui()
	# TEST: Add a fake item immediately
	try_add_item("meteor")
	try_add_item("nuke")

# --- ADDING ITEMS ---
# Returns TRUE if added successfully, FALSE if full
func try_add_item(item_type: String) -> bool:
	# Find the first empty slot
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = item_type
			update_ui()
			return true # Success!
			
	return false # Inventory Full

# --- USING ITEMS ---
func use_item(index: int) -> void:
	var item = slots[index]
	
	if item == null:
		return # Slot is empty, do nothing
		
	print("Activating Power: ", item)
	
	# TODO: Call the Player to actually fire the weapon
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.activate_power_weapon(item)
	
	# Clear the slot
	slots[index] = null
	update_ui()

# --- UPDATE VISUALS ---
func update_ui() -> void:
	for i in range(buttons.size()):
		var item = slots[i]
		var btn = buttons[i]
		
		if item == null:
			btn.text = "Empty"
			btn.disabled = true # Can't click empty slots
			# btn.icon = null
		else:
			btn.text = item # (Temporary: Show text until we have icons)
			btn.disabled = false


func _on_slot_1_pressed() -> void:
	use_item(0)

func _on_slot_2_pressed() -> void:
	use_item(1)

func _on_slot_3_pressed() -> void:
	use_item(2)
