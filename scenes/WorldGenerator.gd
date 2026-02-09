extends Node2D

# --- CONFIGURATION ---
@export var ground_layer: TileMapLayer  # Drag your TileMapLayer here!
@export var noise: FastNoiseLite        # We will configure this in the Editor
@export var player: Node2D              # Assign your Player node here

# --- CHUNK SETTINGS ---
const CHUNK_SIZE: int = 32              # Size of one chunk in tiles (32x32)
const RENDER_DISTANCE: int = 2          # Radius of chunks to load (2 = 5x5 grid)
const UNLOAD_DISTANCE: int = 4
# --- STATE ---
var active_chunks: Dictionary = {}      # Stores coordinates of currently loaded chunks
var current_chunk_coord: Vector2i       # Player's current chunk coordinate

func _ready() -> void:
	# 1. Setup Noise (if not set in editor)
	if not noise:
		noise = FastNoiseLite.new()
		# noise.seed = randi()
		# noise.frequency = 0.05      # Lower = Larger "blobs" of terrain
		#noise.fractal_octaves = FastNoiseLite.FRACTAL_NONE   # Detail level
	
	randomize() 
	noise.seed = randi() # Pick a random integer
	
	add_to_group("world_generator")

	# 2. Initial Load
	update_chunks()
	
	if player:
		# Check if (0,0) is safe. If not, find the nearest safe spot.
		var safe_start = find_safe_start_location()
		
		# If we found a spot that isn't (0,0), move the player!
		if safe_start != Vector2.ZERO:
			print("WorldGenerator: (0,0) was a wall. Moving player to ", safe_start)
			player.global_position = safe_start
			
func _process(_delta: float) -> void:
	if not player: return
	
	# 1. Calculate Player's current Chunk Coordinate
	# We convert pixel position -> tile position -> chunk position
	var p_pos = ground_layer.local_to_map(player.global_position)
	var new_chunk_coord = Vector2i(p_pos.x / CHUNK_SIZE, p_pos.y / CHUNK_SIZE)
	
	# Handle negative coordinates correctly (e.g. -1 / 32 = 0 in integer math, which is wrong)
	if p_pos.x < 0: new_chunk_coord.x -= 1
	if p_pos.y < 0: new_chunk_coord.y -= 1

	# 2. Only update if we moved to a new chunk
	if new_chunk_coord != current_chunk_coord:
		current_chunk_coord = new_chunk_coord
		update_chunks()

func update_chunks() -> void:
	# --- 1. LOAD NEW CHUNKS ---
	for x in range(current_chunk_coord.x - RENDER_DISTANCE, current_chunk_coord.x + RENDER_DISTANCE + 1):
		for y in range(current_chunk_coord.y - RENDER_DISTANCE, current_chunk_coord.y + RENDER_DISTANCE + 1):
			var chunk_coord = Vector2i(x, y)
			if not active_chunks.has(chunk_coord):
				generate_chunk(chunk_coord)
				active_chunks[chunk_coord] = true
	
	# --- 2. UNLOAD OLD CHUNKS (The New Garbage Collector) ---
	var chunks_to_remove: Array[Vector2i] = []
	
	for chunk_coord in active_chunks.keys():
		# Calculate distance from player's current chunk
		var distance = Vector2(chunk_coord).distance_to(Vector2(current_chunk_coord))
		
		# If it's too far away, mark it for death
		if distance > UNLOAD_DISTANCE:
			chunks_to_remove.append(chunk_coord)
	
	# Process the death list
	for chunk_coord in chunks_to_remove:
		unload_chunk(chunk_coord)
	# 3. Unload old chunks (Optional: Memory Cleanup)
	# For now, we just keep them to prevent re-generation lag, but 
	# in a real run we would delete chunks far away.
	# (We can add the "Unload" logic later to keep it simple now)

func generate_chunk(chunk_coord: Vector2i) -> void:
	# Loop through every tile in the 32x32 chunk
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			# Calculate global map coordinates
			var global_x = (chunk_coord.x * CHUNK_SIZE) + x
			var global_y = (chunk_coord.y * CHUNK_SIZE) + y
			
			# Get Noise Value (-1.0 to 1.0)
			var noise_val = noise.get_noise_2d(global_x, global_y)
			
			# --- THE RULES ---
			# Decide what tile to place based on noise height
			var atlas_coord = Vector2i(1,0) # Default: Floor (0,0)
			
			if noise_val > 0.4:
				# Wall / Obstacle
				# Make sure this matches your TileSet atlas coords!
				atlas_coord = Vector2i(0, 0) 
			
			# Paint the tile
			ground_layer.set_cell(Vector2i(global_x, global_y), 0, atlas_coord)

func unload_chunk(chunk_coord: Vector2i) -> void:
	# We "erase" the tiles by setting them to -1 (empty)
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var global_x = (chunk_coord.x * CHUNK_SIZE) + x
			var global_y = (chunk_coord.y * CHUNK_SIZE) + y
			
			# -1 tells Godot to remove the tile completely
			ground_layer.set_cell(Vector2i(global_x, global_y), -1)
	
	# Remove from our tracking dictionary
	active_chunks.erase(chunk_coord)
	
# This allows other scripts (like EnemySpawner) to ask "Is this a wall?"
# even if the wall hasn't been physically created yet.
func is_position_wall(global_pos: Vector2) -> bool:
	if not ground_layer or not noise:
		return false # Safety check
		
	# 1. Convert Pixel Position -> Tile Coordinate
	# We must divide by the tile size (40) to match the loop in generate_chunk
	var tile_pos = ground_layer.local_to_map(global_pos)
	
	# 2. Query the Noise
	# This is the EXACT same math used in generate_chunk
	var noise_val = noise.get_noise_2d(tile_pos.x, tile_pos.y)
	
	# 3. Check the Threshold
	# Must match the "if noise_val > 0.4" logic in generate_chunk
	if noise_val > 0.4:
		return true # It IS a wall (or will be)
	
	return false # It is safe floor

func find_safe_start_location() -> Vector2:
	var search_radius = 0.0
	var max_radius = 1000.0
	
	# We spiral outward looking for a valid floor tile
	while search_radius < max_radius:
		# Check 8 points around the current radius (or just 1 if radius is 0)
		var steps = max(1, int(search_radius / 10)) # More checks as circle gets bigger
		
		for i in range(steps):
			var angle = (TAU / steps) * i
			var offset = Vector2(cos(angle), sin(angle)) * search_radius
			var check_pos = Vector2.ZERO + offset # Checking relative to (0,0)
			
			# Ask the Noise: "Is this a wall?"
			if not is_position_wall(check_pos):
				return check_pos # Found it! This spot is safe.
		
		# Expand the search ring by 40px (roughly one tile)
		search_radius += 40.0
	
	# Fallback: If the world is 100% walls (unlikely), return 0,0
	return Vector2.ZERO
