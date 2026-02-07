extends Node2D

# --- CONFIGURATION ---
@export var ground_layer: TileMapLayer  # Drag your TileMapLayer here!
@export var noise: FastNoiseLite        # We will configure this in the Editor
@export var player: Node2D              # Assign your Player node here

# --- CHUNK SETTINGS ---
const CHUNK_SIZE: int = 32              # Size of one chunk in tiles (32x32)
const RENDER_DISTANCE: int = 2          # Radius of chunks to load (2 = 5x5 grid)

# --- STATE ---
var active_chunks: Dictionary = {}      # Stores coordinates of currently loaded chunks
var current_chunk_coord: Vector2i       # Player's current chunk coordinate

func _ready() -> void:
	# 1. Setup Noise (if not set in editor)
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.05      # Lower = Larger "blobs" of terrain
		noise.fractal_octaves = 3   # Detail level

	# 2. Initial Load
	update_chunks()

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
	var required_chunks: Array[Vector2i] = []
	
	# 1. Identify which chunks SHOULD be visible
	for x in range(current_chunk_coord.x - RENDER_DISTANCE, current_chunk_coord.x + RENDER_DISTANCE + 1):
		for y in range(current_chunk_coord.y - RENDER_DISTANCE, current_chunk_coord.y + RENDER_DISTANCE + 1):
			required_chunks.append(Vector2i(x, y))
	
	# 2. Load missing chunks
	for chunk_coord in required_chunks:
		if not active_chunks.has(chunk_coord):
			generate_chunk(chunk_coord)
			active_chunks[chunk_coord] = true
			
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
