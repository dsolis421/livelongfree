extends CanvasLayer

@onready var arrow = $ArrowSprite
@export var margin: float = 50.0 # How many pixels from the edge of the monitor

func _process(_delta: float) -> void:
	# 1. Find the boss (Assumes your Boss has add_to_group("boss") in its _ready)
	var boss = get_tree().get_first_node_in_group("boss")
	
	if not is_instance_valid(boss):
		arrow.hide()
		return

	# 2. Get the screen size and the Boss's exact position on the monitor
	var screen_rect = get_viewport().get_visible_rect()
	var boss_canvas_pos = boss.get_global_transform_with_canvas().origin
	
	# 3. Create a "Safe Zone" slightly smaller than the screen
	var safe_area = screen_rect.grow(-margin)

	# 4. The Logic
	if safe_area.has_point(boss_canvas_pos):
		# Boss is on-screen! Hide the arrow.
		arrow.hide()
	else:
		# Boss is off-screen! Show the arrow.
		arrow.show()
		
		# Clamp the arrow's position strictly to the edges of the safe zone
		var clamped_pos = boss_canvas_pos
		clamped_pos.x = clamp(clamped_pos.x, margin, screen_rect.size.x - margin)
		clamped_pos.y = clamp(clamped_pos.y, margin, screen_rect.size.y - margin)
		
		arrow.position = clamped_pos
		
		# Rotate the arrow so it points from the edge of the screen directly at the Boss
		var direction = (boss_canvas_pos - clamped_pos).normalized()
		arrow.rotation = direction.angle()
