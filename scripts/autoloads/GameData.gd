extends Node

const SAVE_PATH: String = "user://game_data.dat"
const SECRET_KEY: String = "change_this_to_random_gibberish_string_99!" 

# --- PERSISTENT VARIABLES ---
var gold: int = 0
var high_kills: int = 0
var upgrades: Dictionary = {
	"speed": 0,
	"magnet": 0,
	"damage": 0
}

func _ready() -> void:
	# Print path for debugging
	print("GameData ready. Save path: ", ProjectSettings.globalize_path(SAVE_PATH))
	load_game()

# --- HELPER: Generate Deterministic Hash ---
# We manually combine values so the order never changes
func generate_content_string(data: Dictionary) -> String:
	# 1. Force strict order for the base stats
	var base_str = str(int(data.get("gold", 0))) + str(int(data.get("high_kills", 0)))
	
	# 2. Force strict order for upgrades (Alphabetical or Fixed)
	# We manually pull each known key. Do not trust "str(dict)"!
	var ups = data.get("upgrades", {})
	var upgrade_str = ""
	upgrade_str += str(int(ups.get("damage", 0)))
	upgrade_str += str(int(ups.get("magnet", 0)))
	upgrade_str += str(int(ups.get("speed", 0)))
	
	# 3. Combine with Secret Key
	return base_str + upgrade_str + SECRET_KEY

func save_game() -> void:
	var data = {
		"gold": gold,
		"high_kills": high_kills,
		"upgrades": upgrades
	}
	
	# 1. Generate Hash using our predictable helper
	var content_string = generate_content_string(data)
	var checksum = content_string.sha256_text()
	
	# 2. Package and Write
	var save_package = {
		"data": data,
		"hash": checksum
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_package))
		# print("Game Saved. Gold: ", gold, " | Kills: ", high_kills)
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): 
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) != OK: 
		print("Save file corrupted (JSON Error).")
		return
		
	var save_package = json.data
	if not "data" in save_package or not "hash" in save_package: 
		return
		
	# --- VERIFY THE HASH ---
	# We use the EXACT same helper function to reconstruct the string
	var check_content = generate_content_string(save_package["data"])
	var check_hash = check_content.sha256_text()
	
	if check_hash != save_package["hash"]:
		print("SECURITY ALERT: Save file modified! Deleting corrupted file.")
		# Optional: Delete the file so it doesn't happen again
		DirAccess.remove_absolute(SAVE_PATH)
		return
	
	# --- APPLY DATA ---
	var clean_data = save_package["data"]
	
	gold = int(clean_data.get("gold", 0))
	high_kills = int(clean_data.get("high_kills", 0))
	upgrades = clean_data.get("upgrades", {})
	
	print("Save Loaded Successfully. Gold: ", gold, " Kills: ", high_kills)

func add_gold(amount: int) -> void:
	gold += amount
	save_game()
