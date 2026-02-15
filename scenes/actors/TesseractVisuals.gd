extends Node2D

# Link the squares
@onready var layer_1 = $Layer1_Outer
@onready var layer_2 = $Layer2_Inner
@onready var layer_3 = $Layer3_Mid
@onready var layer_4 = $Layer4_Core

# Rotation Speeds (Negative = Counter-Clockwise)
# Huge outer shell moves slow. Core spins fast.
var speed_1 = 0.5   
var speed_2 = -1.0  
var speed_3 = 2.0   
var speed_4 = -4.0  

func _physics_process(delta: float) -> void:
	# Rotate every layer independently
	layer_1.rotation += speed_1 * delta
	layer_2.rotation += speed_2 * delta
	layer_3.rotation += speed_3 * delta
	layer_4.rotation += speed_4 * delta

# Call this from Boss.gd when taking damage
func play_hurt_animation() -> void:
	var tween = create_tween()
	
	# Flash White (High value "10" makes it bloom if Glow is enabled)
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.05) 
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	
	# The "Implosion" Glitch
	# Shrink the outer layers IN, expand the core OUT
	tween.parallel().tween_property(layer_1, "scale", Vector2(0.5, 0.5), 0.1)
	tween.parallel().tween_property(layer_4, "scale", Vector2(2.0, 2.0), 0.1)
	
	# Snap back to normal with an elastic bounce
	tween.parallel().tween_property(layer_1, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(layer_4, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)

# Call this from Boss.gd when the boss dies
func play_death_animation() -> void:
	var tween = create_tween()
	
	# Optional: Stop the normal rotation by zeroing out speeds
	speed_1 = 0.0
	speed_2 = 0.0
	speed_3 = 0.0
	speed_4 = 0.0
	
	# Define outward directions for each layer (normalized vectors)
	# These point: upper-left, upper-right, lower-left, lower-right
	var dir_1 = Vector2(-1, -1).normalized()  # Layer 1 flies upper-left
	var dir_2 = Vector2(1, -1).normalized()   # Layer 2 flies upper-right
	var dir_3 = Vector2(-1, 1).normalized()   # Layer 3 flies lower-left
	var dir_4 = Vector2(1, 1).normalized()    # Layer 4 flies lower-right
	
	# How far each layer flies (in pixels)
	var fly_distance = 250.0
	
	# Duration of the death animation
	var death_duration = 1.5
	
	# --- THE EXPLOSION ---
	
	# Flash bright white first (like the hurt animation)
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.05)
	
	# Move each layer outward in its direction
	# Using TRANS_EXPO + EASE_OUT gives a fast start that slows down (explosive feel)
	tween.parallel().tween_property(
		layer_1, "position", 
		layer_1.position + (dir_1 * fly_distance), 
		death_duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(
		layer_2, "position", 
		layer_2.position + (dir_2 * fly_distance), 
		death_duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(
		layer_3, "position", 
		layer_3.position + (dir_3 * fly_distance), 
		death_duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(
		layer_4, "position", 
		layer_4.position + (dir_4 * fly_distance), 
		death_duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Add wild spin to each layer as they fly (rotation in radians)
	tween.parallel().tween_property(layer_1, "rotation", layer_1.rotation + 10.0, death_duration)
	tween.parallel().tween_property(layer_2, "rotation", layer_2.rotation - 15.0, death_duration)
	tween.parallel().tween_property(layer_3, "rotation", layer_3.rotation + 20.0, death_duration)
	tween.parallel().tween_property(layer_4, "rotation", layer_4.rotation - 25.0, death_duration)
	
	# Fade out all layers as they fly
	tween.parallel().tween_property(self, "modulate:a", 0.0, death_duration)
	
	# Optional: shrink layers as they fade (adds "dissolving" feel)
	tween.parallel().tween_property(layer_1, "scale", Vector2(0.3, 0.3), death_duration)
	tween.parallel().tween_property(layer_2, "scale", Vector2(0.2, 0.2), death_duration)
	tween.parallel().tween_property(layer_3, "scale", Vector2(0.1, 0.1), death_duration)
	tween.parallel().tween_property(layer_4, "scale", Vector2(0.0, 0.0), death_duration)
	
	# When animation finishes, clean up the boss
	tween.tween_callback(queue_free)
