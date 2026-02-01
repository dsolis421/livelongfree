extends Area2D

# We define the "flavors" of loot
enum TYPE { COMMON, RARE, EPIC, LEGENDARY }

# Configuration for each type (Color + XP Value)
# You can tweak these numbers later!
var stats = {
	TYPE.COMMON:    {"color": Color.WHITE,       "xp": 10},
	TYPE.RARE:      {"color": Color.CYAN,        "xp": 50},
	TYPE.EPIC:      {"color": Color.MAGENTA,     "xp": 200},
	TYPE.LEGENDARY: {"color": Color.ORANGE,      "xp": 1000}
}

var xp_value: int = 10

func _ready() -> void:
	# 1. AUTO-GROUPING (Performance)
	# This ensures the GameManager can wipe this gem on Level Up
	add_to_group("loot")
	
	# 2. DISTANCE CHECK TIMER (Performance)
	# Instead of checking every single frame (expensive!),
	# we create a timer to check only once every 2 seconds.
	var timer = Timer.new()
	timer.wait_time = 2.0 
	timer.autostart = true
	timer.timeout.connect(_check_distance_from_player)
	add_child(timer)

func _check_distance_from_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	# If player is dead or missing, stop checking
	if not player:
		return
		
	# Calculate distance
	var dist = global_position.distance_to(player.global_position)
	
	# 1500px is roughly 1.5 screens away. 
	# If it's that far, the player probably left it behind.
	if dist > 1500.0:
		queue_free()

func setup(type: int) -> void:
	# 1. Set the visual color
	$Sprite2D.modulate = stats[type]["color"]
	
	# 2. Set the internal value
	xp_value = stats[type]["xp"]

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# Deposit the XP
		GameManager.add_experience(xp_value)
		
		# Optional Sound Effect could go here later)
		queue_free()
