# Game Specification: "Survivor Protocol"

**Version:** 1.0.0
**Target Platform:** Android (Google Play Store)
**Engine:** Godot 4.x
**Language:** GDScript
**Render Mode:** Mobile (Vulkan) or Compatibility (GLES3) - _Decision pending hardware test_

---

## 1. Project Overview

**Genre:** Action Roguelite / Reverse Bullet Hell (Vampire Survivor Clone).
**Core Loop:**

1.  **Spawn:** Player appears in an infinite, tiling environment (Parallax).
2.  **Survive:** Enemies spawn continuously at the screen edges (outside the viewport) and move toward the player.
3.  **Auto-Combat:** Weapons fire automatically at the nearest enemies within range; the player does not aim manually.
4.  **Progress:** Enemies drop "Bio-Data" (XP Gems). Collecting enough triggers a Level Up.
5.  **Upgrade:** Player selects 1 of 3 random upgrades (New Weapon or Stat Boost) upon leveling up.
6.  **Fail/Repeat:** Player HP hits 0 -> Game Over -> Meta-progression currency saved -> Main Menu.

---

## 2. Technical Constraints & Best Practices (Strict Enforcement)

### A. Strict Static Typing

To ensure maximum performance on ARM architecture (Mobile CPUs) and prevent runtime errors, all GDScript must be statically typed.

- **Prohibited:** `var speed = 200` or `func get_health():`
- **Mandatory:** `var speed: float = 200.0`
- **Mandatory:** `func get_health() -> int:`

### B. Memory Management (The "No-GC" Rule)

Android creates "stutter" (frame drops) when the Garbage Collector runs. To prevent this, we avoid memory allocation during the game loop.

1.  **Object Pooling:** Never use `instantiate()` or `queue_free()` during gameplay logic.
    - **Setup:** Pre-instantiate (e.g., 200 `Enemy` nodes, 100 `Projectile` nodes) at the Loading Screen.
    - **Runtime:** Use `visible = false`, `process_mode = PROCESS_MODE_DISABLED`, and `set_physics_process(false)` when an entity "dies."
    - **Revival:** When spawning, move a disabled entity to the spawn point, reset its variables (HP, etc.), and re-enable it.
2.  **Resource Preloading:** All textures and audio must be `preload()`-ed in constants at the script top, not `load()`-ed at runtime.

### C. Decoupled Architecture (Signal Bus)

- **Principle:** Nodes must not reference each other directly (e.g., `get_parent().get_node("Player")` is prohibited).
- **Implementation:** Use a global **SignalBus** singleton (Autoload) to pass messages.
  - _Example:_ `SignalBus.enemy_died.emit(xp_value, location_vector)`
  - _Example:_ `SignalBus.player_health_changed.emit(new_health)`

---

## 3. Game Systems & Architecture

### A. Directory Structure

```text
res://
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── scenes/
│   ├── actors/
│   │   ├── player/ (Player.tscn, Player.gd)
│   │   └── enemies/ (EnemyBase.tscn, Skeleton.tscn)
│   ├── combat/
│   │   ├── projectiles/ (Bullet.tscn)
│   │   └── weapons/ (WeaponController.gd)
│   ├── managers/ (Spawner.gd, GameManager.gd)
│   └── ui/ (HUD.tscn, VirtualJoystick.tscn)
├── scripts/
│   ├── autoloads/ (SignalBus.gd, Global.gd)
│   └── components/ (HealthComponent.gd, HitboxComponent.gd, HurtboxComponent.gd)
└── systems/
    └── pooling/ (ObjectPool.gd)B. Player Controller (Player.gd)

* Base Node: CharacterBody2D.
* Physics: Standard move_and_slide() using a normalized velocity vector based on speed.
* Input Handling:
    * Must accept a Vector2 from the Virtual Joystick.
    * Must not rely on Input.is_action_pressed directly for movement logic (to allow for modular input sources).

* Components:
    * HealthComponent: Handles HP and death logic.
    * Area2D (Pickup Radius): Detects XP Gems.

### C. Enemy System (EnemyBase.gd)
* Base Node: CharacterBody2D (for physics separation) or Area2D (for performance, if physics not required).
* Movement Logic:
    * Calculate vector to Player: (player.global_position - global_position).normalized().
    * Apply "Soft Collision" force to prevent enemies from stacking perfectly on top of each other.

* State: Uses ObjectPool logic. When health <= 0:
    * Emit SignalBus.enemy_died.
    * Spawn XP Gem at current position (using XP Pool).
    * Reset state and return to Enemy Pool.

### D. Weapon System
* Auto-Targeting: Weapons scan for bodies in detection_range.
* Performance Optimization: get_closest_enemy() function runs on a Timer (e.g., every 0.1s or 0.2s) rather than _physics_process to save CPU cycles.
* Firing: Requests a Projectile from the Object Pool, sets its rotation/velocity, and enables it.

### E. Component-Based Design
* HealthComponent: Generic node that stores max_health and current_health. Has damage(amount) function. Emits signals on death.
* HitboxComponent (Area2D): The thing that deals damage (e.g., on a bullet).
* HurtboxComponent (Area2D): The thing that receives damage (e.g., on the enemy body).

## 4. Android Specifics

### A. Resolution & Aspect Ratio

* Orientation: Landscape.
* Viewport Width: 1280 (Design resolution).
* Viewport Height: 720.
* Window Override: 1280x720 (for testing).
* Stretch Mode: canvas_items (Ensures 2D assets stay crisp).
* Aspect: expand (Supports 19:9 screens without black bars; UI anchors must be set correctly).

### B. Touch Controls (Virtual Joystick)

* Type: Floating or Fixed Joystick (Bottom-Left).
* Deadzone: 0.2 (Prevents drift).
* Output: Returns a normalized Vector2 (-1.0 to 1.0).
* Visuals: Inner circle moves within outer circle radius.

### C. Export Configuration

* Permissions: Keep minimal. VIBRATE (for haptic feedback on hit) is the only required permission for MVP.
* Architecture: Export AAB (Android App Bundle) supporting arm64-v8a (standard) and armeabi-v7a (older devices).
* Icons: Must generate adaptive icons for Android 12+.

### 5. Development Phases (Roadmap)

Phase 1: The "Grey Box" Prototype (MVP)

* [ ] Set up SignalBus and GameManager Singletons.
* [ ] Create VirtualJoystick UI scene and script.
* [ ] Create Player scene (Blue Square) controlled by Joystick.
* [ ] Create basic ObjectPool system (Generic script).
* [ ] Create EnemySpawner: Spawn red squares at screen edge that chase player.
* [ ] Success Criteria: Player moves smoothly on Android device (APK build); Enemies spawn and recycle without frame drops.

Phase 2: Combat & Core Loop

* [ ] Implement Hitbox and Hurtbox components.
* [ ] Implement WeaponBase: Auto-fires projectile (Yellow Square) at nearest enemy.
* [ ] Implement HealthComponent and Damage logic (Enemies flash white on hit).
* [ ] XP Gems implementation (Green Squares) and Pickup logic.
* [ ] Success Criteria: Can play a full "loop" (Kill Enemy -> Drop XP -> Collect XP).

Phase 3: "Juice" & Polish (Mobile Feel)

* [ ] Replace squares with Sprites (Kenney.nl assets or similar).
* [ ] Add "Screen Shake" on damage (Camera2D offset).
* [ ] Add "Damage Numbers" pop-up (also pooled).
* [ ] Android Haptic Feedback integration.
* [ ] Main Menu and Game Over screens.
```
