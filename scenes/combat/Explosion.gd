extends Area2D

@export var damage: int = 100

func _ready() -> void:
	# 1. OPTIONAL: Randomize rotation for variety
	rotation = randf() * TAU
	
	# 2. Play the animation immediately
	$AnimationPlayer.play("explode")

# This function will be called by the Animation Player
func deal_damage() -> void:
	# Get everything inside the red circle
	var bodies = get_overlapping_bodies()
	print("Explosion touching ", bodies.size(), " objects.") # Debug
	for body in bodies:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			print("BOOM! Hit enemy: ", body.name) # DEBUG
			body.take_damage(damage)

# This function will be called at the end of the animation
func cleanup() -> void:
	queue_free()
