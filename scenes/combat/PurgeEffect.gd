extends CanvasLayer

@onready var anim_player = $AnimationPlayer

func _ready() -> void:
	if anim_player:
		anim_player.play("purge_blast")
	else:
		print("CRITICAL: Animation Player Not Found")
	# Wait for animation to finish, then delete
	await anim_player.animation_finished
	queue_free()
