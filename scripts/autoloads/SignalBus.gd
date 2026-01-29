extends Node

# --- SignalBus.gd ---
# The Central Nervous System of "Survivor Protocol".
# ALL cross-system communication happens here.

# COMBAT SIGNALS
# Emitted when an enemy reaches 0 HP.
# @param xp_reward: Amount of experience points the enemy drops.
# @param death_location: World position where the XP gem should spawn.
signal enemy_died(xp_reward: int, death_location: Vector2)

# PLAYER SIGNALS
# Emitted when the player takes damage or heals.
signal player_health_changed(current_hp: int, max_hp: int)

# Emitted when the player gains a level.
signal player_leveled_up(new_level: int)

# SYSTEM SIGNALS
# Emitted when the game loop should stop (Player died).
signal game_over
