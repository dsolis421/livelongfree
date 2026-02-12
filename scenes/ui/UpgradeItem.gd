extends PanelContainer

# --- CONFIGURATION ---
@export var upgrade_key: String = ""  # Matches keys in GameData (e.g., "speed")
@export var icon_texture: Texture2D

# --- NODES ---
@onready var icon: TextureRect = $MarginContainer/HBoxContainer/Icon
@onready var name_label: Label = $MarginContainer/HBoxContainer/InfoBox/NameLabel
@onready var level_label: Label = $MarginContainer/HBoxContainer/InfoBox/LevelLabel
@onready var buy_button: Button = $MarginContainer/HBoxContainer/BuyButton

func _ready() -> void:
	add_to_group("upgrade_items") # Allows the Store to find all rows
	
	if icon_texture:
		icon.texture = icon_texture
	
	buy_button.pressed.connect(_on_buy_pressed)
	refresh_ui()

func refresh_ui() -> void:
	# 1. Fetch Data
	var current_level = GameData.get_upgrade_level(upgrade_key)
	var cost = GameData.get_upgrade_cost(upgrade_key)
	var config = GameData.UPGRADE_CONFIG.get(upgrade_key, {})
	
	# 2. Update Text
	name_label.text = config.get("name", "Unknown Upgrade")
	var max_lvl = config.get("max_level", 10)
	level_label.text = "Level %d / %d" % [current_level, max_lvl]
	
	# 3. Handle Button State
	if cost == -1:
		buy_button.text = "MAXED"
		buy_button.disabled = true
	else:
		buy_button.text = str(cost) + " G"
		# Check wallet: Disable if too expensive
		buy_button.disabled = (GameData.gold < cost)

func _on_buy_pressed() -> void:
	if GameData.purchase_upgrade(upgrade_key):
		# Refresh THIS row
		refresh_ui()
		# Refresh ALL rows (because buying this might make others unaffordable)
		get_tree().call_group("upgrade_items", "refresh_ui")
		# Update the Total Gold Display (in parent scene)
		get_tree().call_group("store_ui", "update_gold_display")
