extends Area2D

@export var speed = 400
@export var damage: float = 1.0
@export var knockback_force: float = 500.0

var direction = Vector2.RIGHT

func _ready() -> void:
	# 1. SCREEN EXIT (Keep this, it's good)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# 2. LIFETIME TIMER (The Safety Net)
	# This guarantees the bullet is deleted after 5 seconds, 
	# preventing "Minefields" in the void.
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# (Removed debug prints to clean up console)
	
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(int(damage))
		
		if body.has_method("take_knockback"):
			body.take_knockback(global_position, knockback_force)
			
		queue_free()

# Keep this if you connected the signal via the Editor
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
