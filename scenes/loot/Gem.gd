extends Area2D

# --- CONFIGURATION ---
enum TYPE { COMMON, RARE, EPIC, LEGENDARY, GOLD }

var stats = {
	TYPE.COMMON:    {"color": Color.WHITE,       "val": 10,   "is_gold": false},
	TYPE.RARE:      {"color": Color.CYAN,        "val": 50,   "is_gold": false},
	TYPE.EPIC:      {"color": Color.MAGENTA,     "val": 100,  "is_gold": false},
	TYPE.LEGENDARY: {"color": Color.GREEN,      "val": 200,  "is_gold": false},
	TYPE.GOLD:      {"color": Color(1, 0.85, 0), "val": 20,    "is_gold": true} 
}

# --- STATE VARIABLES ---
var current_value: int = 10
var is_currency: bool = false
var target: Node2D = null  # The player, once magnetized

@export var speed: float = 400.0        # Starting fly speed
@export var acceleration: float = 1200.0 # How fast it speeds up while flying

func _ready() -> void:
	# 1. GROUPS
	add_to_group("loot")

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 3. DESPAWN TIMER
	var timer = Timer.new()
	timer.wait_time = 2.0 
	timer.autostart = true
	timer.timeout.connect(_check_distance_from_player)
	add_child(timer)

func _physics_process(delta: float) -> void:
	# --- MAGNET MOVEMENT ---
	if target:
		# 1. Calculate direction to player
		var direction = (target.global_position - global_position).normalized()
		
		# 2. Move towards them
		position += direction * speed * delta
		
		# 3. Accelerate over time (makes it feel "snappy")
		speed += acceleration * delta

func setup(type: int) -> void:
	# 1. Get Data
	var data = stats.get(type, stats[TYPE.COMMON])
	
	# 2. Apply Visuals
	# Ensure you have a Sprite2D node named "Sprite2D"
	if has_node("Sprite2D"):
		$Sprite2D.modulate = data["color"]
	
	# 3. Apply Logic
	current_value = data["val"]
	is_currency = data["is_gold"]

# --- MAGNET DETECTION ---
func _on_area_entered(area: Area2D) -> void:
	# If we are already flying, ignore other areas
	print("Gem hit area: ", area.name)
	if target: return
		
	# Check for the Magnet
	if area.name == "MagnetArea":
		target = area.get_parent()
		speed += 100.0 # Initial boost

# --- ACTUAL PICKUP ---
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		
		# 1. Give Rewards
		if is_currency:
			GameManager.add_gold(current_value)
		else:
			GameManager.add_experience(current_value)
			
		# 2. Destroy Object
		queue_free()

# --- OPTIMIZED CLEANUP ---
func _check_distance_from_player() -> void:
	# If we are currently flying toward the player, DO NOT despawn!
	if target: return

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		# 1500px is roughly off-screen + buffer
		if dist > 1500.0:
			queue_free()
