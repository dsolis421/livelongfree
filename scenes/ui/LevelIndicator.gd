extends Control

@export var max_level: int = 5
@export var current_level: int = 0
@export var active_color: Color = Color.CYAN
@export var inactive_color: Color = Color(0.2, 0.3, 0.3)

# The exact fixed size of the triangle footprint
@export var shape_width: float = 225.0 
@export var shape_height: float = 80.0 

func update_levels(current: int, max_lvl: int) -> void:
	current_level = current
	max_level = max_lvl
	queue_redraw() 

func _draw() -> void:
	if max_level <= 0: return

	# 1. THE CENTERING MATH
	var x_offset = (size.x - shape_width) / 2.0
	var y_offset = (size.y - shape_height) / 2.0

	# 2. DRAW THE BACKGROUND TRIANGLE (The empty track)
	var bg_p1 = Vector2(x_offset, y_offset + shape_height)               # Bottom-Left
	var bg_p2 = Vector2(x_offset + shape_width, y_offset + shape_height) # Bottom-Right
	var bg_p3 = Vector2(x_offset + shape_width, y_offset)                # Top-Right
	
	var bg_points = PackedVector2Array([bg_p1, bg_p2, bg_p3])
	draw_colored_polygon(bg_points, inactive_color)

	# 3. DRAW THE FOREGROUND TRIANGLE (The filled progress)
	if current_level > 0:
		# Get the percentage of completion (e.g., 2 / 5 = 0.4)
		var fill_ratio = float(current_level) / float(max_level)
		fill_ratio = clamp(fill_ratio, 0.0, 1.0) # Safety catch

		# Calculate how wide and tall the filled portion should be
		var fill_width = shape_width * fill_ratio
		var fill_height = shape_height * fill_ratio

		var fg_p1 = Vector2(x_offset, y_offset + shape_height)                       # Bottom-Left
		var fg_p2 = Vector2(x_offset + fill_width, y_offset + shape_height)          # Bottom-Right of fill
		var fg_p3 = Vector2(x_offset + fill_width, y_offset + shape_height - fill_height) # Top-Right of fill

		var fg_points = PackedVector2Array([fg_p1, fg_p2, fg_p3])
		draw_colored_polygon(fg_points, active_color)
