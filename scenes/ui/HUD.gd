extends CanvasLayer

@onready var score_label = $TopBar/HBoxContainer/ScoreLabel
@onready var timer_label = $TopBar/HBoxContainer/TimerLabel

func _process(delta: float) -> void:
	# 1. Update Score Text
	score_label.text = "KILLS: " + str(GameManager.kills)
	
	# 2. Format Time (Minutes:Seconds)
	var minutes = int(GameManager.time_elapsed / 60)
	var seconds = int(GameManager.time_elapsed) % 60
	
	# "%02d" is a fancy way to say "add a zero if it's less than 10" (e.g., 05 instead of 5)
	timer_label.text = "%02d:%02d" % [minutes, seconds]
