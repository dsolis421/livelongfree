extends Area2D

@export var speed = 400
@export var damage: float = 1.0
@export var knockback_force: float = 800.0

var direction = Vector2.RIGHT

var bounce_count: int = 0       # Set by Player.gd
var bounce_range: float = 400.0 # How far to scan for next target
var already_hit: Array[Node2D] = [] # Memory to avoid hitting same enemy twice

func _ready() -> void:
	# --- NEW: ALIGN ROTATION ---
	# Turn the bullet to face its travel direction immediately.
	# (Requires 'direction' to be set by the spawner before adding to scene)
	rotation = direction.angle()
	
	# SCREEN EXIT (Keep this, it's good)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# LIFETIME TIMER
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)
	
	# Get the current upgrade level once
	var dmg_level = GameData.get_upgrade_level("damage")
	
	# --- 1. VISUAL WEIGHT (Particle Amount) ---
	# Read the base amount you set in the Inspector (e.g., 10 or 15)
	var base_particles: int = $SparkTrail.amount 
	# Add 5 extra sparks per upgrade level (Level 5 = +25 sparks!)
	var bonus_particles: int = dmg_level * 10 
	
	# Apply the new amount (Must be cast to int)
	$SparkTrail.amount = int(base_particles + bonus_particles)
	
	
	# --- 2. GLOW INTENSITY (Brightness) ---
	# Base multiplier is 1.0. Each level adds 0.5 brightness.
	var glow_modifier: float = 1.0 + (dmg_level * 2)
	var base_color: Color = Color(1.0, 1.0, 1.0, 1.0) # Change to your trail's base color
	
	$SparkTrail.modulate = Color(
		base_color.r * glow_modifier,
		base_color.g * glow_modifier,
		base_color.b * glow_modifier,
		1.0 # Keep Alpha solid
	)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	
	# --- VISUAL VARIANCE (Electric Effect) ---
	# 1. Jitter the sprite up and down (Position Noise)
	$Sprite2D.offset.y = randf_range(-2.0, 2.0)
	
	# 2. Jitter the rotation slightly (Angle Noise)
	# This makes the bolt look unstable, like it's vibrating
	var current_angle = direction.angle()
	rotation = current_angle + randf_range(-0.1, 0.1) # +/- 5 degrees wobble
	
	# 3. Flicker the brightness (Energy Noise)
	var energy = randf_range(0.8, 1.5)
	$Sprite2D.modulate.a = energy
	$SparkTrail.modulate.a = randf_range(0.5, 1.5)

func _on_body_entered(body: Node2D) -> void:
	
	if body is TileMapLayer or body is TileMap or body is StaticBody2D:
		queue_free() # Destroy bullet
	
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(int(damage))
		
		if body.has_method("take_knockback"):
			body.take_knockback(global_position, knockback_force)
		
		already_hit.append(body)
		if bounce_count > 0:
			if attempt_ricochet(body):
				return # We found a target! Don't destroy bullet.
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func attempt_ricochet(current_victim: Node2D) -> bool:
	bounce_count -= 1
	
	var nearest_enemy = null
	var min_dist_sq = bounce_range * bounce_range # Compare Squared Distance (Faster)
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		# Validation Checks
		if not is_instance_valid(enemy): continue
		if enemy == current_victim: continue
		if enemy in already_hit: continue # Don't hit the same guy twice
		
		# Find the closest one
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			nearest_enemy = enemy
	
	if nearest_enemy:
		# Found one! Update direction for physics_process
		direction = global_position.direction_to(nearest_enemy.global_position)
		
		# Reset rotation immediately (physics_process will jitter it later)
		rotation = direction.angle()
		
		return true # Tell body_entered we survived
		
	return false # No target found, let the bullet die
