extends Control

# --- CONFIGURATION ---
const MAX_SLOTS = 4

# Use preloads if you have icons, otherwise use text for now
const ICON_LOCKED = preload("res://assets/LLF_ActiveLock.png")
const ICON_OPEN = preload("res://assets/LLF_ActiveDir.png")  

# --- STATE ---
# Expanded to 6 slots. null = empty.
var slots = [null, null, null, null, null, null]

# UPDATED: Now referencing all 6 buttons
@onready var buttons = [
	$HBoxContainer/Slot1, 
	$HBoxContainer/Slot2, 
	$HBoxContainer/Slot3,
	$HBoxContainer/Slot4
]
@onready var game = GameData

func _ready() -> void:
	add_to_group("hud")
	# Force UI update on load
	update_ui()

# --- ADDING ITEMS ---
func try_add_item(item_type: String) -> bool:
	# CRITICAL CHANGE: Only scan up to the UNLOCKED limit
	# var limit = GameData.unlocked_active_slots
	var limit = get_unlocked_slot_count() # Replaces GameData.unlocked_active_slots
	for i in range(limit):
		if slots[i] == null:
			slots[i] = item_type
			update_ui()
			return true # Success!
			
	return false # Inventory Full (or no open unlocked slots)

# --- USING ITEMS ---
func use_item(index: int) -> void:
	# Safety: Don't allow using locked slots (even if bugged)
	#if index >= GameData.unlocked_active_slots:
	#	return

	if index >= get_unlocked_slot_count(): return
	
	var item = slots[index]
	
	if item == null:
		return 
		
	print("Activating Power: ", item)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.activate_power_weapon(item)
	
	# Clear the slot
	slots[index] = null
	update_ui()

# --- UPDATE VISUALS (The New Logic) ---
func update_ui() -> void:
	# var unlocked_count = GameData.unlocked_active_slots
	var unlocked_count = get_unlocked_slot_count()
	
	
	for i in range(buttons.size()):
		var item = slots[i]
		var btn = buttons[i]
		
		
		# CASE 1: LOCKED SLOT
		if i >= unlocked_count:
			# btn.text = "LOCKED"
			btn.disabled = true
			btn.icon = ICON_LOCKED
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0) # Grayed out
		# CASE 2: EMPTY UNLOCKED SLOT
		elif item == null:
			btn.text = ""
			btn.disabled = true
			btn.icon = ICON_OPEN 
			btn.modulate = Color(1, 1, 1, 1.0) # Faint
		# CASE 3: FILLED SLOT
		else:
			var data = game.item_data[item]
			btn.text = "" # Or use icons here
			btn.disabled = false
			btn.icon = data.icon
			btn.modulate = Color.WHITE

func _on_slot_1_pressed() -> void:
	use_item(0)
func _on_slot_2_pressed() -> void:
	use_item(1)
func _on_slot_3_pressed() -> void:
	use_item(2)
func _on_slot_4_pressed() -> void: 
	use_item(3)

func get_unlocked_slot_count() -> int:
	# Level 0 = 1 Slot. Level 5 = 6 Slots.
	return 1 + GameData.get_upgrade_level("slots")
