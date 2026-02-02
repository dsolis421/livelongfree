extends CanvasLayer

func _ready() -> void:
	$AnimationPlayer.play("nuke_blast")
	# Wait for animation to finish, then delete
	await $AnimationPlayer.animation_finished
	queue_free()
