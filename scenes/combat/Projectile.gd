extends Area2D

@export var speed = 400
@export var damage: float = 1.0 # Added variable
@export var knockback_force: float = 500.0 # Standard impact

var direction = Vector2.RIGHT

func _ready() -> void:
	# When the bullet leaves the screen, delete it
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Move in the direction we were fired
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# If we hit an enemy, kill it (We will add this logic next)
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(int(damage))
		if body.has_method("take_knockback"):
			body.take_knockback(global_position, knockback_force)
		queue_free() # Destroy the bullet on impact


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
