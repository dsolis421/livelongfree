extends Area2D

@export var speed: float = 800.0
@export var spin_speed: float = 15.0
@export var damage: int = 500

var direction: Vector2 = Vector2.ZERO

func _ready():
	# Make the star point in the direction it is flying
	rotation = direction.angle()
	
	# Connect the signals via code for safety
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation += spin_speed * delta
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
			# Do NOT queue_free() here! This allows it to pierce through infinitely.
			
	elif body.is_in_group("environment") or body is TileMap:
		# Hits a wall -> Destroy it
		queue_free()
