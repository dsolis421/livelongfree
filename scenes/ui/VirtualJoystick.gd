extends Control
class_name VirtualJoystick

# --- EXPORTS ---
# IMPORTANT: Since you changed the hierarchy, make sure to re-assign 
# these nodes in the Inspector if they disconnected!
@export var joystick_base: TextureRect
@export var joystick_tip: TextureRect
@export var deadzone: float = 0.2
@export var clamp_distance: float = 80.0

# --- INTERNAL VARIABLES ---
var _touch_index: int = -1

func _ready() -> void:
	# Force center the stick immediately when the game loads
	_reset_joystick()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				# Input logic uses GLOBAL coordinates (Screen space)
				var global_center = _get_global_base_center()
				var distance = event.position.distance_to(global_center)
				
				# Check if touch is inside the base radius
				if distance < clamp_distance * 1.5:
					_touch_index = event.index
		
		elif event.index == _touch_index:
			# Finger lifted
			_reset_joystick()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			# Calculate the vector from the GLOBAL center to the finger
			var global_center = _get_global_base_center()
			var vector = event.position - global_center
			
			# Clamp the movement
			if vector.length() > clamp_distance:
				vector = vector.normalized() * clamp_distance
			
			_update_tip_position(vector)

func _get_global_base_center() -> Vector2:
	# Used for INPUT detection only (Comparing against screen touches)
	if joystick_base:
		return joystick_base.global_position + (joystick_base.size / 2)
	return global_position

func _update_tip_position(vector: Vector2) -> void:
	# Move the visual tip relative to the Base
	# Since Tip is a child of Base, (0,0) is the Base's top-left corner.
	if joystick_tip and joystick_base:
		
		# 1. Find the center of the Base (Locally)
		var center_local = joystick_base.size / 2
		
		# 2. Offset for the tip's own size (so the sprite centers on the point)
		var tip_half_size = joystick_tip.size / 2
		
		# 3. Apply: Center + Vector - TipOffset
		joystick_tip.position = center_local + vector - tip_half_size

func _reset_joystick() -> void:
	_touch_index = -1
	_update_tip_position(Vector2.ZERO)

# --- PUBLIC API ---
func get_output() -> Vector2:
	if joystick_tip and joystick_base:
		# Calculate vector based on Tip position relative to Base Center
		var center_local = joystick_base.size / 2
		var tip_center = joystick_tip.position + (joystick_tip.size / 2)
		
		var vector = tip_center - center_local
		
		# Normalize
		if vector.length() > 0:
			var normalized = vector / clamp_distance
			if normalized.length() < deadzone:
				return Vector2.ZERO
			return normalized
			
	return Vector2.ZERO
