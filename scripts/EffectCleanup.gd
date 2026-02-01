extends GPUParticles2D

func _ready() -> void:
	# Force restart to ensure it plays from the beginning
	restart()
	emitting = true
	
	# Connect the signal
	finished.connect(_on_finished)

func _on_finished() -> void:
	queue_free()
