extends Area2D

var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var lifetime: float = 3.0

func _ready() -> void:
	# Auto-destroy after 3 seconds so we don't lag the game
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func setup(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free() # Bullet destroys itself on impact
