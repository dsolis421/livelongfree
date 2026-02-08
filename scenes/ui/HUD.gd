extends CanvasLayer

@onready var score_label = $SafeArea/TopBar/HBoxContainer/ScoreLabel
@onready var timer_label = $SafeArea/TopBar/HBoxContainer/TimerLabel
@onready var gold_label = $SafeArea/TopBar/HBoxContainer/GoldLabel
@onready var boss_health_bar = $BossHealthBar
@onready var boss_warning_label = $BossWarningLabel
@onready var flash_rect = $FlashRect
# We access the AnimationPlayer to play the warning flash
# @onready var anim_player = $AnimationPlayer

func _ready() -> void:
	# 1. Connect BOSS Signals
	# We listen to the GameManager for when to show/hide these
	GameManager.boss_incoming_warning.connect(_on_boss_warning)
	GameManager.boss_health_initialized.connect(_on_boss_spawn)
	GameManager.boss_health_changed.connect(_on_boss_hit)
	GameManager.boss_cleared_ui.connect(_on_boss_cleared)
	GameManager.boss_supernova_flash.connect(_on_supernova)
	
	# 2. Set Default State
	boss_health_bar.visible = false
	boss_warning_label.visible = false
	
	# If you have Score/Timer logic in _process or other signals, keep it here!
	
func _on_boss_warning() -> void:
	boss_warning_label.visible = true
	
	# OPTION A: If you made an Animation in the Editor called "flash"
	# anim_player.play("flash")
	
	# OPTION B: Code-based Tween (Easier, no AnimationPlayer setup needed)
	var tween = create_tween()
	boss_warning_label.modulate.a = 0.0 # Start invisible
	# Fade In
	tween.tween_property(boss_warning_label, "modulate:a", 1.0, 0.5)
	# Wait 2 seconds
	tween.tween_interval(2.0)
	# Fade Out
	tween.tween_property(boss_warning_label, "modulate:a", 0.0, 0.5)
	# Turn off visibility
	tween.tween_callback(func(): boss_warning_label.visible = false)
	
func _on_boss_spawn(max_hp: int) -> void:
	# Wake up the Health Bar
	boss_health_bar.max_value = max_hp
	boss_health_bar.value = max_hp
	boss_health_bar.visible = true

func _on_boss_hit(new_hp: int) -> void:
	# Animate the bar sliding down
	var tween = create_tween()
	tween.tween_property(boss_health_bar, "value", new_hp, 0.1).set_trans(Tween.TRANS_SINE)

func _on_boss_cleared() -> void:
	# Boss is dead, hide the evidence
	boss_health_bar.visible = false
	boss_warning_label.visible = false

func _process(delta: float) -> void:
	# 1. UPDATE TIMER
	# Read the single source of truth from GameManager
	var time = GameManager.time_remaining
	
	# Clamp to 0 so it doesn't show negative numbers
	if time < 0: 
		time = 0
	
	# Update the text using the cached variable
	timer_label.text = format_time(int(time))
	
	# 2. UPDATE SCORE (Kills)
	score_label.text = "Kills: " + str(GameManager.kills)
	
	# 3. UPDATE GOLD
	# We check if gold_label is valid just in case you haven't added the node yet
	if gold_label:
		gold_label.text = "Bounty: " + str(GameManager.gold_current_run)

func _on_supernova() -> void:
	var tween = create_tween()
	# Instant white
	tween.tween_property(flash_rect, "modulate:a", 1.0, 0.1)
	# Fade out slowly
	tween.tween_property(flash_rect, "modulate:a", 0.0, 1.5)

func format_time(seconds: int) -> String:
	var minutes = seconds / 60
	var secs = seconds % 60
	return "%02d:%02d" % [minutes, secs]
