extends Control

@onready var anim = $AnimationPlayer
@onready var panel = $PanelContainer
@onready var title = $PanelContainer/HBoxContainer/VBoxContainer/Title
@onready var desc = $PanelContainer/HBoxContainer/VBoxContainer/Desc
@onready var icon = $PanelContainer/HBoxContainer/Icon

func _ready() -> void:
	# 1. REGISTER MYSELF
	# Tell the global manager: "I am the active popup window."
	GameManager.achievement_popup = self
	
	# 2. HIDE INITIALLY (Optional safety)
	# visible = false # Or let the animation handle it

func show_medal(key: String):
	# 1. Setup the UI Data
	if not GameData.ACHIEVEMENT_DATA.has(key): return
	var data = GameData.ACHIEVEMENT_DATA[key]
	
	title.text = data.name
	desc.text = data.description
	icon.texture = data.icon
	
	# 2. Play the Animation
	# The 'stop()' ensures that if we are already playing one, 
	# it resets to the start immediately.
	anim.stop()
	anim.play("slide_in")

func _exit_tree() -> void:
	# 3. CLEANUP: "I am leaving!"
	# If we change scenes, we must tell GameManager we are gone
	# so it doesn't try to call a dead node.
	if GameManager.achievement_popup == self:
		GameManager.achievement_popup = null
