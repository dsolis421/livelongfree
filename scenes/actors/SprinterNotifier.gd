extends VisibleOnScreenNotifier2D

func _ready() -> void:
	# Connect the signal to itself via code so you don't even have 
	# to click around in the Node tab!
	screen_entered.connect(_on_screen_entered)

func _on_screen_entered() -> void:
	AudioManager.play_sfx("sprinter")
