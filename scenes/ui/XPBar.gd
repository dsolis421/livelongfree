extends ProgressBar

func _ready() -> void:
	# 1. Initialize logic
	value = 0
	
	# 2. Connect to Manager
	GameManager.xp_updated.connect(update_bar)
	
	# 3. Set initial state (in case we restart)
	max_value = GameManager.target_experience
	value = GameManager.experience

func update_bar(current_xp: int, target_xp: int) -> void:
	# Update the max first (in case level up changed the target)
	max_value = target_xp
	
	# Animate the value for smoothness (Optional, but looks pro)
	# If you want instant, just use: value = current_xp
	var tween = create_tween()
	tween.tween_property(self, "value", current_xp, 0.2).set_trans(Tween.TRANS_SINE)
