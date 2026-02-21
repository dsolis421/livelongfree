extends PanelContainer

@onready var icon_rect = $HBoxContainer/Icon
@onready var name_label = $HBoxContainer/VBoxContainer/NameLabel
@onready var desc_label = $HBoxContainer/VBoxContainer/DescLabel

func set_medal_data(key: String, data: Dictionary, is_unlocked: bool):
	# 1. Set Text
	name_label.text = data.name
	desc_label.text = data.description
	
	# 2. Set Icon (if it exists)
	if data.has("icon"):
		icon_rect.texture = data.icon
	
	# 3. Handle Locked State
	if is_unlocked:
		# Full Color
		modulate = Color(1, 1, 1, 1) 
		icon_rect.modulate = Color(1, 1, 1, 1)
	else:
		# Dark / Silhouette
		# We dim the whole panel to look "disabled"
		modulate = Color(0.5, 0.5, 0.5, 1) 
		# We turn the icon BLACK so it's a mystery silhouette
		icon_rect.modulate = Color(0, 0, 0, 1) 
		name_label.text = "???" # Optional: Hide the name
