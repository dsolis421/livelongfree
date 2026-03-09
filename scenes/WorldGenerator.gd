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
var _generation_thread: Thread = Thread.new()
var _pending_chunks: Array[Vector2i] = []   # Chunks waiting to be generated
var _completed_chunks: Dictionary = {}       # Finished map_data waiting to be painted
var _thread_mutex: Mutex = Mutex.new()       # Prevents simultaneous read/write crashes
var chunk_cache: Dictionary = {}  # Stores map_data for previously generated chunks
var _exit_thread: bool = false

func _ready() -> void:
	if not noise:
		noise = FastNoiseLite.new()
	
	randomize() 
	noise.seed = randi() 
	add_to_group("world_generator")

	var start_chunk = Vector2i(0, 0)
	var initial_map = _build_map_data(start_chunk)
	initial_map = _smooth_chunk(initial_map, start_chunk)
	_paint_chunk(initial_map, start_chunk)
	active_chunks[start_chunk] = true

	update_chunks()
			
func _process(_delta: float) -> void:
	if not player: return
	
	# Paint any chunks that finished generating
	# This happens on the main thread where TileMap access is safe
	_thread_mutex.lock()
	var chunks_to_paint = _completed_chunks.duplicate()
	_completed_chunks.clear()
	_thread_mutex.unlock()
	
	for chunk_coord in chunks_to_paint:
		_paint_chunk(chunks_to_paint[chunk_coord], chunk_coord)
	
	# Your existing player chunk tracking (unchanged)
	var p_pos = ground_layer.local_to_map(player.global_position)
	var new_chunk_coord = Vector2i(p_pos.x / CHUNK_SIZE, p_pos.y / CHUNK_SIZE)
	if p_pos.x < 0: new_chunk_coord.x -= 1
	if p_pos.y < 0: new_chunk_coord.y -= 1
	if new_chunk_coord != current_chunk_coord:
		current_chunk_coord = new_chunk_coord
		update_chunks()

func update_chunks() -> void:
	# --- LOAD NEW CHUNKS ---
	for x in range(current_chunk_coord.x - RENDER_DISTANCE, current_chunk_coord.x + RENDER_DISTANCE + 1):
		for y in range(current_chunk_coord.y - RENDER_DISTANCE, current_chunk_coord.y + RENDER_DISTANCE + 1):
			var chunk_coord = Vector2i(x, y)
			if not active_chunks.has(chunk_coord):
				active_chunks[chunk_coord] = true 
				
				# LOCK THE DOOR BEFORE TOUCHING THE ARRAY
				_thread_mutex.lock()
				_pending_chunks.append(chunk_coord) 
				_thread_mutex.unlock()
	
	# Kick off the thread if it's not already running
	if not _generation_thread.is_alive() and _pending_chunks.size() > 0:
		# Clean up the old zombie thread before making a new one
		if _generation_thread.is_started():
			_generation_thread.wait_to_finish() 
			
		_generation_thread = Thread.new()
		_generation_thread.start(_generate_pending_chunks)
	
	# --- UNLOAD OLD CHUNKS (unchanged) ---
	var chunks_to_remove: Array[Vector2i] = []
	for chunk_coord in active_chunks.keys():
		var distance = Vector2(chunk_coord).distance_to(Vector2(current_chunk_coord))
		if distance > UNLOAD_DISTANCE:
			chunks_to_remove.append(chunk_coord)
	for chunk_coord in chunks_to_remove:
		unload_chunk(chunk_coord)

func generate_chunk(chunk_coord: Vector2i) -> void:
	# --- STEP 1: Build raw map data from noise ---
	# Instead of painting tiles immediately, we collect all decisions
	# into a 2D array first so we can smooth it before painting.
	
	# map_data[x][y] = 1 means wall, 0 means floor
	var map_data: Array = []
	
	for x in range(CHUNK_SIZE):
		var column = []
		for y in range(CHUNK_SIZE):
			var global_x = (chunk_coord.x * CHUNK_SIZE) + x
			var global_y = (chunk_coord.y * CHUNK_SIZE) + y
			
			var noise_val = noise.get_noise_2d(global_x, global_y)
			
			# Same rule as before — just storing it instead of painting it
			if noise_val > 0.5:
				column.append(1)  # Wall
			else:
				column.append(0)  # Floor
		map_data.append(column)
	
	# --- STEP 2: Smooth the raw data ---
	# Run cellular automata passes to eliminate jagged corners
	# and isolated wall spurs that trap enemies
	map_data = _smooth_chunk(map_data, chunk_coord)  # ← pass chunk_coord
	
	# --- STEP 3: Paint the smoothed data to the TileMap ---
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var global_x = (chunk_coord.x * CHUNK_SIZE) + x
			var global_y = (chunk_coord.y * CHUNK_SIZE) + y
			
			# Same atlas coords you were already using
			var atlas_coord = Vector2i(1, 0)  # Floor
			if map_data[x][y] == 1:
				atlas_coord = Vector2i(0, 0)  # Wall
			
			ground_layer.set_cell(Vector2i(global_x, global_y), 0, atlas_coord)
			
func _generate_pending_chunks() -> void:
	# This runs on the background thread.
	
	while true:
		# 1. LOCK THE DOOR to safely look at the pending list
		_thread_mutex.lock()
		# 2. Check if we are done. If yes, unlock and exit the loop!
		if _pending_chunks.size() == 0 or _exit_thread:
			_thread_mutex.unlock()
			break
		# 3. Safely grab the next chunk in line
		var chunk_coord = _pending_chunks.pop_front()
		# 4. UNLOCK THE DOOR immediately so the main thread can keep appending
		_thread_mutex.unlock()
		# --- HEAVY MATH (Happens outside the lock so the game stays smooth) ---
		var map_data = _build_map_data(chunk_coord)
		map_data = _smooth_chunk(map_data, chunk_coord)
		# 5. LOCK THE DOOR again to safely hand the finished data back to the main thread
		_thread_mutex.lock()
		_completed_chunks[chunk_coord] = map_data
		_thread_mutex.unlock()

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

func _smooth_chunk(map_data: Array, chunk_coord: Vector2i) -> Array:
	var passes = 4
	for i in range(passes):
		map_data = _smooth_pass(map_data, chunk_coord)
	map_data = _remove_isolated_walls(map_data, chunk_coord)
	return map_data


func _smooth_pass(map_data: Array, chunk_coord: Vector2i) -> Array:
	var new_map: Array = []
	var threshold = 4
	
	for x in range(CHUNK_SIZE):
		var column = []
		for y in range(CHUNK_SIZE):
			# Pass chunk_coord so out-of-bounds uses noise, not hardcoded wall
			var wall_count = _count_wall_neighbors(map_data, x, y, chunk_coord)
			
			if wall_count > threshold:
				column.append(1)
			elif wall_count < threshold:
				column.append(0)
			else:
				column.append(map_data[x][y])
		new_map.append(column)
	
	return new_map

func _count_wall_neighbors(map_data: Array, x: int, y: int, chunk_coord: Vector2i) -> int:
	# Count how many of the 8 surrounding tiles are walls.
	# For neighbors outside this chunk, we query noise directly
	# instead of assuming wall — this prevents the chunk corner bias
	# that was always walling off the player spawn at (0,0).
	
	var count = 0
	
	for nx in range(x - 1, x + 2):
		for ny in range(y - 1, y + 2):
			if nx == x and ny == y:
				continue  # Skip the tile itself
			
			if nx < 0 or nx >= CHUNK_SIZE or ny < 0 or ny >= CHUNK_SIZE:
				# Out of bounds — ask noise what this tile WILL be,
				# rather than blindly calling it a wall
				var global_x = (chunk_coord.x * CHUNK_SIZE) + nx
				var global_y = (chunk_coord.y * CHUNK_SIZE) + ny
				var noise_val = noise.get_noise_2d(global_x, global_y)
				count += 1 if noise_val > 0.5 else 0
			else:
				count += map_data[nx][ny]
	
	return count

func _remove_isolated_walls(map_data: Array, chunk_coord: Vector2i) -> Array:
	for x in range(1, CHUNK_SIZE - 1):
		for y in range(1, CHUNK_SIZE - 1):
			if map_data[x][y] == 1:
				if _count_wall_neighbors(map_data, x, y, chunk_coord) <= 2:
					map_data[x][y] = 0
	return map_data
	
# This allows other scripts (like EnemySpawner) to ask "Is this a wall?"
# even if the wall hasn't been physically created yet.
func is_position_wall(global_pos: Vector2) -> bool:
	if not ground_layer:
		return false  # Safety check
	
	# Convert pixel position to tile coordinate
	var tile_pos = ground_layer.local_to_map(global_pos)
	
	# Read the ACTUAL painted tile from the TileMap.
	# This respects smoothing — whatever was physically painted is the truth.
	# get_cell_atlas_coords() returns Vector2i(-1,-1) if the cell is empty.
	var atlas_coord = ground_layer.get_cell_atlas_coords(tile_pos)
	
	# Vector2i(0, 0) is your wall tile atlas coordinate.
	# Adjust this if your wall tile uses different atlas coords.
	return atlas_coord == Vector2i(0, 0)

func _build_map_data(chunk_coord: Vector2i) -> Array:
	if chunk_cache.has(chunk_coord):
		return chunk_cache[chunk_coord]
	
	var map_data: Array = []
	var safe_spawn_radius = 6.0 # 6 tiles (roughly 200 pixels) of guaranteed safety
	
	for x in range(CHUNK_SIZE):
		var column = []
		for y in range(CHUNK_SIZE):
			var global_x = (chunk_coord.x * CHUNK_SIZE) + x
			var global_y = (chunk_coord.y * CHUNK_SIZE) + y
			
			# Check how far this specific tile is from (0,0)
			var distance_from_center = Vector2(global_x, global_y).distance_to(Vector2.ZERO)
			
			if distance_from_center <= safe_spawn_radius:
				# FORCED CARVE: Always a floor
				column.append(0)
			else:
				# NORMAL LOGIC: Ask the noise
				var noise_val = noise.get_noise_2d(global_x, global_y)
				column.append(1 if noise_val > 0.5 else 0)
				
		map_data.append(column)
	
	chunk_cache[chunk_coord] = map_data
	return map_data

func _paint_chunk(map_data: Array, chunk_coord: Vector2i) -> void:
	# TileMap writes — must be on main thread
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var global_x = (chunk_coord.x * CHUNK_SIZE) + x
			var global_y = (chunk_coord.y * CHUNK_SIZE) + y
			var atlas_coord = Vector2i(0, 0) if map_data[x][y] == 1 else Vector2i(1, 0)
			ground_layer.set_cell(Vector2i(global_x, global_y), 0, atlas_coord)
	# 2. Calculate the exact pixel size and position of this chunk
	var tile_size = ground_layer.tile_set.tile_size
	var chunk_pixel_size = Vector2(CHUNK_SIZE * tile_size.x, CHUNK_SIZE * tile_size.y)
	
	# chunk_coord is a grid coordinate (e.g., 1, 0). Multiply by size to get screen pixels.
	var chunk_pixel_pos = Vector2(chunk_coord.x * chunk_pixel_size.x, chunk_coord.y * chunk_pixel_size.y)
	
	# 3. Create a pitch-black shadow block over the chunk
	var shadow = ColorRect.new()
	shadow.color = Color.BLACK
	shadow.size = chunk_pixel_size
	shadow.global_position = chunk_pixel_pos
	
	# 4. Add it to the WorldGenerator (NOT the TileMap) so it draws on top
	add_child(shadow)
	
	# 5. Smoothly fade the shadow away to reveal the newly generated tiles
	var tween = create_tween()
	# Fades from black to fully transparent over 0.6 seconds
	tween.tween_property(shadow, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	
	# 6. Delete the shadow block to free up computer memory once it's invisible
	tween.tween_callback(shadow.queue_free)
	
func _exit_tree() -> void:
	# 1. Flip the kill switch so the thread loop breaks
	_exit_thread = true
	
	# 2. If the thread is currently doing math, wait for it to finish its current loop
	if _generation_thread.is_started():
		_generation_thread.wait_to_finish()
		print("WorldGenerator: Background thread safely shut down.")
		
# --- BIOS PURGE SPAWN LOGIC ---
func get_spawn_coordinates(center_pos: Vector2, min_radius: float, max_radius: float) -> Dictionary:
	# Tries to find a wall tile that is touching a floor tile.
	# Returns a Dictionary: {"wall_pos": Vector2, "floor_pos": Vector2, "is_wall": bool}
	
	var max_attempts = 50 # Prevents infinite loops. 50 checks takes < 1 millisecond.
	
	# 1. SEARCH FOR AN INFECTED WALL EDGE
	for i in range(max_attempts):
		# Pick a random point in the donut ring around the player
		var angle = randf() * TAU
		var dist = randf_range(min_radius, max_radius)
		var check_pos = center_pos + Vector2(cos(angle), sin(angle)) * dist
		
		# Snap that pixel coordinate to the TileMap grid
		var tile_coords = ground_layer.local_to_map(check_pos)
		
		# Is this tile a wall? (Atlas coord 0,0)
		var atlas_coord = ground_layer.get_cell_atlas_coords(tile_coords)
		if atlas_coord == Vector2i(0, 0): 
			
			# It's a wall! Now check its 4 orthogonal neighbors (Up, Down, Left, Right)
			var neighbors = [ Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1) ]
			neighbors.shuffle() # Shuffle so enemies don't always peel in the same direction
			
			for offset in neighbors:
				var neighbor_coords = tile_coords + offset
				var neighbor_atlas = ground_layer.get_cell_atlas_coords(neighbor_coords)
				
				# If the neighbor is a floor tile (Atlas coord 1,0), we found our edge!
				if neighbor_atlas == Vector2i(1, 0): 
					return {
						# map_to_local converts the grid coordinate back to an exact pixel position
						"wall_pos": ground_layer.map_to_local(tile_coords),
						"floor_pos": ground_layer.map_to_local(neighbor_coords),
						"is_wall": true # Tells the spawner to use the wall-peel animation
					}
					
	# 2. THE FALLBACK (The "Glitch Puddle")
	# If the player is in a massive open room, we might not find a wall in 50 attempts.
	# In that case, we find a random floor tile so the horde never stops.
	for i in range(max_attempts):
		var angle = randf() * TAU
		var dist = randf_range(min_radius, max_radius)
		var check_pos = center_pos + Vector2(cos(angle), sin(angle)) * dist
		var tile_coords = ground_layer.local_to_map(check_pos)
		
		if ground_layer.get_cell_atlas_coords(tile_coords) == Vector2i(1, 0): # Floor
			var local_pos = ground_layer.map_to_local(tile_coords)
			return {
				"wall_pos": local_pos, # Same as floor, so no movement happens
				"floor_pos": local_pos,
				"is_wall": false # Tells the spawner to just pop them out of the floor
			}
			
	# 3. ABSOLUTE FAILSAFE (Should practically never happen)
	return {
		"wall_pos": center_pos,
		"floor_pos": center_pos,
		"is_wall": false
	}
