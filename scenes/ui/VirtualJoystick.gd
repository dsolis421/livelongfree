extends Control
class_name VirtualJoystick

# --- EXPORTS ---
@export var joystick_base: TextureRect
@export var joystick_tip: TextureRect
@export var deadzone: float = 0.2
@export var clamp_distance: float = 100.0

# --- INTERNAL VARIABLES ---
var _touch_index: int = -1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				# FIX: Calculate distance from the VISUAL center, not the Node origin
				var center = _get_base_center()
				var distance = event.position.distance_to(center)
				
				# Debug Print to verify we are clicking the right spot
				# print("Click Dist: ", distance, " | Allowed: ", clamp_distance * 1.5)
				
				# Check if touch is inside the base radius (with some buffer)
				if distance < clamp_distance * 1.5:
					_touch_index = event.index
		
		elif event.index == _touch_index:
			# Finger lifted
			_reset_joystick()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			var center = _get_base_center()
			var vector = event.position - center
			
			# Clamp the visual tip movement
			if vector.length() > clamp_distance:
				vector = vector.normalized() * clamp_distance
			
			_update_tip_position(vector)

func _get_base_center() -> Vector2:
	# Returns the global center position of the Base texture
	if joystick_base:
		return joystick_base.global_position + (joystick_base.size / 2)
	return global_position

func _update_tip_position(vector: Vector2) -> void:
	# Move the visual tip relative to the Base center
	if joystick_tip and joystick_base:
		# Center of base relative to the Tip's parent
		var base_center_local = joystick_base.position + (joystick_base.size / 2)
		# Offset for the tip size (so it centers)
		var tip_offset = joystick_tip.size / 2
		
		joystick_tip.position = base_center_local - tip_offset + vector

func _reset_joystick() -> void:
	_touch_index = -1
	_update_tip_position(Vector2.ZERO)

# --- PUBLIC API ---
func get_output() -> Vector2:
	if joystick_tip and joystick_base:
		# Calculate vector based on Tip position relative to Base Center
		var base_center_local = joystick_base.position + (joystick_base.size / 2)
		var tip_center_local = joystick_tip.position + (joystick_tip.size / 2)
		
		var vector = tip_center_local - base_center_local
		
		# Normalize
		if vector.length() > 0:
			var normalized = vector / clamp_distance
			if normalized.length() < deadzone:
				return Vector2.ZERO
			return normalized
			
	return Vector2.ZERO
