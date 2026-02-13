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
