extends Area2D

# We define the "flavors" of loot
# Added GOLD to the list
enum TYPE { COMMON, RARE, EPIC, LEGENDARY, GOLD }

# Configuration for each type
var stats = {
	TYPE.COMMON:    {"color": Color.WHITE,       "val": 10,   "is_gold": false},
	TYPE.RARE:      {"color": Color.CYAN,        "val": 50,   "is_gold": false},
	TYPE.EPIC:      {"color": Color.MAGENTA,     "val": 100,  "is_gold": false},
	TYPE.LEGENDARY: {"color": Color.ORANGE,      "val": 200, "is_gold": false},
	TYPE.GOLD:      {"color": Color(1, 0.85, 0), "val": 1,    "is_gold": true} 
	# Note: Gold value is usually low (1-10) because you collect lots of it!
}

var current_value: int = 10
var is_currency: bool = false

func _ready() -> void:
	# 1. AUTO-GROUPING
	add_to_group("loot")
	
	# 2. DISTANCE CHECK TIMER
	var timer = Timer.new()
	timer.wait_time = 2.0 
	timer.autostart = true
	timer.timeout.connect(_check_distance_from_player)
	add_child(timer)

func _process(delta: float) -> void:
	# If you have existing magnet logic here, keep it!
	
	# --- CLEANUP LOGIC ---
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 1500px is about 1.5 screens away. If the player left it behind, delete it.
		if global_position.distance_to(player.global_position) > 1500.0:
			queue_free()
			
func _check_distance_from_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
		
	var dist = global_position.distance_to(player.global_position)
	if dist > 1500.0:
		queue_free()

func setup(type: int) -> void:
	# 1. Get the data from our config
	var data = stats.get(type, stats[TYPE.COMMON]) # Fallback to COMMON if error
	
	# 2. Apply Visuals
	$Sprite2D.modulate = data["color"]
	
	# Optional: If you have a specific "Coin" sprite, you could swap it here:
	# if data["is_gold"]:
	#    $Sprite2D.texture = load("res://assets/coin.png")
	
	# 3. Apply Internal Logic
	current_value = data["val"]
	is_currency = data["is_gold"]

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"): # Safer than checking name == "Player"
		
		# --- THE SPLIT LOGIC ---
		if is_currency:
			# It's Gold!
			GameManager.add_gold(current_value)
			# Optional: Play "Ching" sound
		else:
			# It's XP!
			GameManager.add_experience(current_value)
			# Optional: Play "Ping" sound
		queue_free()
