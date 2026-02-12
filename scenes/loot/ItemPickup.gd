extends Area2D

# The specific type of this item (meteor, nuke, heal)
var item_type: String = ""
const ICON_NUKE = preload("res://assets/LLF_purge.png")
const ICON_METEOR = preload("res://assets/LLF_sigkill.png")
# const ICON_SHIELD = preload("res://assets/pickups/icon_shield.png")
# Fallback texture if something goes wrong
const ICON_DEFAULT = preload("res://assets/LLF_ActiveDir.png")
# Visual settings for each type (Color for now, Texture later)
# We use a Dictionary to map "Type Name" -> Color
var item_data = {
	"SigKill": {
		"icon": ICON_METEOR,
		"color": Color(1.0, 0.2, 0.2, 0.3), # Red Glow
	},
	"Purge": {
		"icon": ICON_NUKE,
		"color": Color(0.2, 1.0, 0.2, 0.3), # Green Glow
	},
	"invincible": {
		"icon": ICON_DEFAULT,
		"color": Color(1.0, 1.0, 0.0, 0.3), # Gold Glow
	}
}

@onready var sprite = $Sprite2D
@onready var glow = $GlowSprite # Make sure you added this node!

func setup(type: String) -> void:
	item_type = type
	
	# Update Visuals based on type
	if type in item_data:
		var data = item_data[type]
		
		# 1. Set the Icon
		sprite.texture = data["icon"]
		sprite.modulate = Color.WHITE # Reset modulation so we see the actual PNG colors!
		glow.modulate = data["color"]
	else:
		# Fallback for unknown items
		sprite.texture = ICON_DEFAULT
		glow.modulate = Color(0.5,0.5,0.5,0.3)
		
func _ready() -> void:
	# Add a floating animation so it looks enticing
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", -5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.set_loops()
	body_entered.connect(_on_body_entered)
	
	# Create a timer to check distance every 1 second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_distance)
	add_child(timer)
	
func _process(_delta: float) -> void:

	# --- CLEANUP LOGIC ---
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 2000px allows a bit more leeway for rare items
		if global_position.distance_to(player.global_position) > 2000.0:
			queue_free()
			
func _check_distance() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	# Calculate distance
	var dist = global_position.distance_to(player.global_position)
	
	# If we are more than 1500 pixels away (about 1.5 screen widths)
	if dist > 1500.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var hud = get_tree().get_first_node_in_group("hud")
		
		if hud and hud.has_method("try_add_item"):
			var success = hud.try_add_item(item_type)
			
			if success:
				print("Picked up: ", item_type)
				queue_free()
			else:
				# Inventory full - Do NOT delete self.
				# The player saw it was a Meteor and couldn't pick it up.
				# They can come back for it later!
				print("CRITICAL: HUD NOT FOUND")
				pass
