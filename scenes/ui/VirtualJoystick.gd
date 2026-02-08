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
	modulate.a = 0.0
	
func _notification(what: int) -> void:
	# 1. If the joystick itself gets hidden/shown (e.g. by a parent menu)
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_reset_joystick()

	# 2. If the game window loses focus (User alt-tabs or a system popup appears)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_joystick()
		
	# 3. If the node is paused (Mode: Process)
	elif what == NOTIFICATION_PAUSED:
		_reset_joystick()

func _input(event: InputEvent) -> void:
	# 1. HANDLE TOUCH START (Click)
	if event is InputEventScreenTouch:
		if event.pressed:
			# Only activate if we aren't already dragging another finger
			if _touch_index == -1:
				# A. Snap the Base to the finger position
				# (We subtract half size to center the joystick on the cursor)
				global_position = event.position - (size / 2)
				
				# B. Make it visible
				modulate.a = 0.7 
				
				# C. Start tracking this specific finger/mouse click
				_touch_index = event.index
		
		# 2. HANDLE TOUCH END (Release)
		elif event.index == _touch_index:
			_reset_joystick()

	# 3. HANDLE DRAGGING
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			var global_center = _get_global_base_center()
			var vector = event.position - global_center
			
			# Clamp the distance so the tip doesn't leave the base
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
	
	# Fade out or Hide when released
	modulate.a = 0.0 # Change to 0.2 if you want a faint ghost of the joystick

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
