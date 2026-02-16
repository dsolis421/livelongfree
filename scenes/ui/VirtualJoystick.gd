extends Control
class_name VirtualJoystick

# --- EXPORTS ---
@export var joystick_base: TextureRect
@export var joystick_tip: TextureRect
@export var deadzone: float = 0.2
@export var clamp_distance: float = 80.0

# --- INTERNAL VARIABLES ---
var _touch_index: int = -1

func _ready() -> void:
	# 1. FORCE PIVOT TO CENTER
	# This ensures that rotation happens "in place" rather than swinging the sprite around.
	if joystick_base:
		joystick_base.pivot_offset = joystick_base.size / 2
		
	if joystick_tip:
		joystick_tip.pivot_offset = joystick_tip.size / 2
		
	# 2. Reset visibility
	_reset_joystick()
	modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
func _input(event: InputEvent) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				# 1. Move Base to Finger
				if joystick_base:
					# Use the same logic for placement (Control node usually isn't rotated, just the texture)
					global_position = event.position - (joystick_base.size / 2)
				
				_touch_index = event.index
				modulate.a = 0.35
				
				# --- ADD THIS: FORCE CENTER ON SPAWN ---
				# Ensures the tip is dead center the moment it appears
				_update_tip_position(Vector2.ZERO)
		
		elif event.index == _touch_index:
			_reset_joystick()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			# Calculate vector in GLOBAL (Screen) space
			var global_center = _get_global_base_center()
			var global_vector = event.position - global_center
			
			# Clamp length
			if global_vector.length() > clamp_distance:
				global_vector = global_vector.normalized() * clamp_distance
			
			_update_tip_position(global_vector)

func _get_global_base_center() -> Vector2:
	if joystick_base:
		# Correct way for Control Nodes:
		# Multiply the Global Transform matrix by the Local Center vector
		return joystick_base.get_global_transform() * (joystick_base.size / 2)
	return global_position

func _update_tip_position(global_vector: Vector2) -> void:
	if joystick_tip and joystick_base:
		var center_local = joystick_base.size / 2
		var tip_half_size = joystick_tip.size / 2
		
		# --- THE FIX (VISUALS) ---
		# Convert the Screen Vector (Right) into the Base's Local Space (Diagonal)
		# We rotate BACKWARDS by the base's rotation.
		var local_vector = global_vector.rotated(-joystick_base.rotation)
		
		joystick_tip.position = center_local + local_vector - tip_half_size

func _reset_joystick() -> void:
	_touch_index = -1
	_update_tip_position(Vector2.ZERO)
	modulate.a = 0.0 # Hide

func get_output() -> Vector2:
	if joystick_tip and joystick_base:
		# 1. Get the LOCAL vector (How the tip looks inside the base)
		var center_local = joystick_base.size / 2
		var tip_center = joystick_tip.position + (joystick_tip.size / 2)
		var local_vector = tip_center - center_local
		
		# 2. --- THE FIX (OUTPUT) ---
		# Convert that Local Vector back to Global Screen Space
		# We rotate FORWARD by the base's rotation.
		var global_vector = local_vector.rotated(joystick_base.rotation)
		
		if global_vector.length() > 0:
			var normalized = global_vector / clamp_distance
			if normalized.length() < deadzone:
				return Vector2.ZERO
			return normalized
			
	return Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_joystick()
		
func _exit_tree() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	set_process_input(false)
	set_process_unhandled_input(false)
