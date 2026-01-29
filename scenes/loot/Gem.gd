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

func setup(type: int) -> void:
	# 1. Set the visual color
	$Sprite2D.modulate = stats[type]["color"]
	
	# 2. Set the internal value
	xp_value = stats[type]["xp"]

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# TODO: Give XP to player
		print("Collected Gem! XP: ", xp_value)
		queue_free()
