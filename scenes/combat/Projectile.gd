extends Area2D

@export var speed = 400
@export var damage: float = 1.0
@export var knockback_force: float = 500.0

var direction = Vector2.RIGHT

func _ready() -> void:
	# --- NEW: ALIGN ROTATION ---
	# Turn the bullet to face its travel direction immediately.
	# (Requires 'direction' to be set by the spawner before adding to scene)
	rotation = direction.angle()
	
	# 1. SCREEN EXIT (Keep this, it's good)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# 2. LIFETIME TIMER
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	
	# --- VISUAL VARIANCE (Electric Effect) ---
	# 1. Jitter the sprite up and down (Position Noise)
	$Sprite2D.offset.y = randf_range(-2.0, 2.0)
	
	# 2. Jitter the rotation slightly (Angle Noise)
	# This makes the bolt look unstable, like it's vibrating
	var current_angle = direction.angle()
	rotation = current_angle + randf_range(-0.1, 0.1) # +/- 5 degrees wobble
	
	# 3. Flicker the brightness (Energy Noise)
	var energy = randf_range(0.8, 1.5)
	$Sprite2D.modulate.a = energy

func _on_body_entered(body: Node2D) -> void:
	
	if body is TileMapLayer or body is TileMap or body is StaticBody2D:
		queue_free() # Destroy bullet
	
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(int(damage))
		
		if body.has_method("take_knockback"):
			body.take_knockback(global_position, knockback_force)
			
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
