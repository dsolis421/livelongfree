extends Area2D

var speed = 400
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
			body.take_damage()
		queue_free() # Destroy the bullet on impact
