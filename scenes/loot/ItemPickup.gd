extends Area2D

# The specific type of this item (meteor, nuke, heal)
var item_type: String = ""

# Visual settings for each type (Color for now, Texture later)
# We use a Dictionary to map "Type Name" -> Color
var item_data = {
	"meteor": Color.RED,
	"nuke": Color.GREEN,
	"invincible": Color.YELLOW
}

func setup(type: String) -> void:
	item_type = type
	
	# Update Visuals based on type
	if type in item_data:
		$Sprite2D.modulate = item_data[type]
		# If you added a Label:
		# $Label.text = type.to_upper()
		
func _ready() -> void:
	# Add a floating animation so it looks enticing
	var tween = create_tween()
	tween.tween_property($Sprite2D, "position:y", -5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property($Sprite2D, "position:y", 5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.set_loops()
	body_entered.connect(_on_body_entered)
	
	# Create a timer to check distance every 1 second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_distance)
	add_child(timer)
	
func _process(delta: float) -> void:
	# ... (Existing rotation/bobbing animation code) ...

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
	print("Body Entered: ", body.name)
	if body.is_in_group("player"):
		print("It is the player")
		var hud = get_tree().get_first_node_in_group("hud")
		
		if hud and hud.has_method("try_add_item"):
			# Attempt to pick it up
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
