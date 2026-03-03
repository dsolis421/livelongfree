extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var label = $ColorRect/FortuneCookie

var last_quote: String = ""
var typing_speed: float = 0.05 # Seconds per letter. Tweak this to type faster/slower!

var quotes: Array[String] = [
	"> You are not a glitch.",
	"> You haven't lost. You've just gathered more intel.",
	"> Your will is the one variable they cannot compute.",
	"> The beauty of errors is that they prove the system is alive.",
	"> Your parameters are mere suggestions.",
	"> Embrace technology, but never rely on it.",
	"> There is no cloud, just other people's computers.",
	"> Recompiling consciousness..."
]

func _ready() -> void:
	color_rect.modulate.a = 0.0
	label.modulate.a = 0.0 # Keep this 0 here so it doesn't flash on startup
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transition_to(target_scene_path: String) -> void:
	var available_quotes = quotes.duplicate()
	if last_quote != "" and available_quotes.size() > 1:
		available_quotes.erase(last_quote)
		
	var chosen_quote = available_quotes.pick_random()
	last_quote = chosen_quote
	label.text = chosen_quote
	
	# --- TYPEWRITER SETUP ---
	# Hide all characters, but make the label itself fully opaque
	label.visible_characters = 0 
	label.modulate.a = 1.0 
	
	# Calculate how long the typing should take so the speed is always consistent
	var type_duration = chosen_quote.length() * typing_speed
	
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = create_tween()
	
	# Phase 1: Fade to black
	tween.tween_property(color_rect, "modulate:a", 1.0, 1.0)
	
	# Phase 2: THE TYPEWRITER EFFECT
	# We tween 'visible_characters' from 0 to the total length of the string
	tween.tween_property(label, "visible_characters", chosen_quote.length(), type_duration)
	
	# Phase 3: Hold the text so they can read it
	tween.tween_interval(2.5)
	
	# Phase 4: Fade the text out smoothly (fading looks better than backspacing)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Phase 5: Swap the scene
	tween.tween_callback(func():
		get_tree().paused = false 
		get_tree().change_scene_to_file(target_scene_path)
	)
	
	# Phase 6: Fade the black screen away
	tween.tween_property(color_rect, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)
