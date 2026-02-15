extends Node2D

signal extraction_complete
signal insertion_complete

@onready var sprite = $Sprite2D
@onready var audio = AudioManager

var player_target: Node2D

func start_insertion(player: Node2D) -> void:
	# 1. SETUP: Hide the player initially (They are inside the ship!)
	player.scale = Vector2.ZERO
	player.modulate.a = 0.0
	
	# Disable controls immediately so they don't shoot inside the ship
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
		
	# Start Drone high above
	var drop_zone = player.global_position
	global_position = drop_zone + Vector2(0, -800)
	visible = true
	
	print("Drone Insertion!")
	audio.start_loop("agent_drone")
	# AudioManager.play_sfx("agent_drone")
	# 2. ANIMATION SEQUENCE
	var tween = create_tween()
	
	# A. Fly In (Fast)
	tween.tween_property(self, "global_position", drop_zone, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# B. Deploy Player (Scale Up)
	tween.tween_callback(func(): print("DEPLOYING AGENT..."))
	tween.parallel().tween_property(player, "scale", Vector2(1, 1), 0.3)
	tween.parallel().tween_property(player, "modulate:a", 1.0, 0.3)
	
	# C. Wait a beat
	tween.tween_interval(0.5)
	
	# D. Fly Away
	var exit_pos = drop_zone + Vector2(0, -1000)
	tween.tween_property(self, "global_position", exit_pos, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# E. Start the Game
	# AudioManager.stop_loop("agent_drone", true)
	tween.tween_callback(_on_insertion_finished)

func _on_insertion_finished() -> void:
	emit_signal("insertion_complete")
	audio.stop_loop("agent_drone", true)
	queue_free()
	
func start_extraction(player: Node2D) -> void:
	player_target = player
	
	# 1. Start Position: Way off-screen (Top)
	# We assume the drone is hovering high above the map
	global_position = player.global_position + Vector2(0, -800)
	visible = true
	
	print("Drone Extraction!")
	audio.start_loop("agent_drone")
	# 2. Disable Player Controls (So they don't wander off)
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
		# Optional: turn off collision so enemies don't nudge them
		if player.has_node("CollisionShape2D"):
			player.get_node("CollisionShape2D").set_deferred("disabled", true)

	# --- THE CINEMATIC TWEEN ---
	var tween = create_tween()
	
	# A. Fly Down to Player (2.0 seconds)
	var landing_pos = player.global_position + Vector2(0, -10) # Hover slightly above
	tween.tween_property(self, "global_position", landing_pos, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# B. "Beam Up" Effect (0.5 seconds)
	# We shrink the player and fade them out to look like they entered the ship
	tween.tween_callback(func(): print("BOARDING..."))
	tween.parallel().tween_property(player, "scale", Vector2.ZERO, 0.5)
	tween.parallel().tween_property(player, "modulate:a", 0.0, 0.5)
	
	# C. Wait a beat (0.5 seconds)
	tween.tween_interval(0.5)
	
	# D. Fly Away (1.5 seconds)
	var exit_pos = landing_pos + Vector2(0, -1000) # Fly back up
	tween.tween_property(self, "global_position", exit_pos, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# E. Trigger Win Screen
	tween.tween_callback(_finish_mission)

func _finish_mission() -> void:
	print("PLAYER SECURED. MISSION ACCOMPLISHED.")
	emit_signal("extraction_complete")
	
	# Call the Manager to show the UI
	GameManager.on_extraction_complete()
	queue_free()
