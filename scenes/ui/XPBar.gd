extends ProgressBar

@onready var current_label = $CurrentLevelLbl
@onready var next_label = $NextLevelLbl

func _ready() -> void:
	# 1. Initialize logic
	value = 0
	
	# 2. Connect to Manager
	GameManager.xp_updated.connect(update_bar)
	update_bar(GameManager.experience, GameManager.target_experience)

func update_bar(current_xp: int, target_xp: int) -> void:
	max_value = target_xp
	
	# Animate the bar
	var tween = create_tween()
	tween.tween_property(self, "value", current_xp, 0.2).set_trans(Tween.TRANS_SINE)
	
	# --- NEW: Update Text Labels ---
	if current_label:
		current_label.text = "Lvl " + str(GameManager.level)
		
	if next_label:
		next_label.text = "Lvl " + str(GameManager.level + 1)
