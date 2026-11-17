## Every hand-tuned look value of the run in one place: daylight, bloom, eggs, player readability,
## obstacle warnings, shadows and wind. Change a number here and re-run; nothing else has to be
## touched. Feature flags (FEATURE_*) switch a whole effect off if it costs too much on a phone.
## Names of the neon era are kept (some are read by player.gd, obstacle_base.gd and
## pickup_system.gd); the ones that no longer drive anything are marked "legacy".
class_name VisualTuning
extends RefCounted

# --- Daylight (BiomeDirector) ------------------------------------------------------------------
## Sun (DirectionalLight3D) energy and the sky-tinted ambient energy.
const SUN_ENERGY: float = 1.0
const AMBIENT_ENERGY: float = 0.75
## Real directional shadows from the sun on quality Medium / High (Low: off).
const FEATURE_SUN_SHADOWS: bool = true
## Shadow range per quality preset (metres from the camera): short = sharp and cheap.
const SUN_SHADOW_DISTANCE: Array[float] = [0.0, 42.0, 60.0]
## How dark the sun shadows are (1 = only ambient light inside them).
const SUN_SHADOW_OPACITY: float = 0.86
## Tonemapper, exposure and the final colour adjustment (Medium / High only).
const TONEMAP_MODE: Environment.ToneMapper = Environment.TONE_MAPPER_FILMIC
const TONEMAP_EXPOSURE: float = 1.0
const ADJUST_CONTRAST: float = 1.06
const ADJUST_SATURATION: float = 1.03
const ADJUST_BRIGHTNESS: float = 1.0

# --- Glow / bloom (WorldEnvironment, applied by BiomeDirector) ---------------------------------
## Subtle: only the true emissives (lava, torch flames, power-up inlays, egg glints) bloom.
const GLOW_INTENSITY: float = 0.45
const GLOW_STRENGTH: float = 0.9
## Bloom adds glow to EVERYTHING, not only bright pixels. 0 = only HDR-bright pixels glow.
const GLOW_BLOOM: float = 0.0
## Only pixels brighter than this glow. Eggs are capped below it (COIN_MAX_BRIGHTNESS), and so is
## sunlit stone, so daylight never blooms.
const GLOW_HDR_THRESHOLD: float = 1.25
const GLOW_HDR_SCALE: float = 1.3
const GLOW_BLEND_MODE: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_SCREEN
## Tonemapper white point. Higher = brights roll off later.
const TONEMAP_WHITE: float = 5.0

# --- Eggs (the collectible; the "coin" names are kept for the code that reads them) ------------
const EGG_HEIGHT: float = 0.32
const EGG_RADIUS: float = 0.112
const EGG_SHELL_COLOR: Color = Color(0.98, 0.92, 0.76)
## Eggs cast a small real sun shadow (when shadows are on).
const EGG_SHADOWS: bool = true
## Legacy: the old coin disc size (the egg uses EGG_HEIGHT / EGG_RADIUS).
const COIN_RADIUS: float = 0.21
const COIN_THICKNESS: float = 0.05
## Eggs shrink to nothing between these two distances from the camera (metres), so an egg can
## never fill the screen.
const COIN_NEAR_FADE_START: float = 4.5
const COIN_NEAR_FADE_END: float = 2.0
## An egg is removed once it is this far behind the player (metres, +Z). Must stay above the
## pickup window (PickupSystem.COLLECT_Z = 0.9) or eggs would vanish before being collected.
const COIN_BEHIND_KILL_Z: float = 1.6
## Brightness cap of the egg colour, kept under GLOW_HDR_THRESHOLD.
const COIN_MAX_BRIGHTNESS: float = 1.05

# --- Player readability ------------------------------------------------------------------------
const FEATURE_PLAYER_RIM: bool = true
## Sunlit rim on the caveman's and the pterosaur's silhouette (character_toon.gdshader, set by
## CavemanModel.apply_rim; view-angle based, no extra pass). Warm and soft in daylight.
const PLAYER_RIM_COLOR: Color = Color(1.0, 0.9, 0.72)
const PLAYER_RIM_STRENGTH: float = 0.45
## Higher = thinner rim.
const PLAYER_RIM_POWER: float = 2.8
## Obstacles whose far edge is this many metres behind the player are hidden, so passed
## obstacles never stand between the camera and the runner.
const HIDE_PASSED_OBSTACLES_Z: float = 1.0

# --- Obstacle warning --------------------------------------------------------------------------
## Fog (horizon haze) starts this far away: obstacles read clearly from further out. Scaled per
## biome by BiomeDef.fog_density_scale (the misty swamp starts earlier).
const FOG_START: float = 80.0
## Painted warnings are not lights: no fog piercing, no emission, a slow gentle pulse.
const WARNING_FOG_PIERCE: float = 0.0
const WARNING_GLOW: float = 0.0
const WARNING_PULSE_SPEED: float = 2.5
const WARNING_PULSE_AMOUNT: float = 0.15
## Ochre chevrons painted on the stone path in front of a barrier.
const FEATURE_LANE_WARNING: bool = true
const LANE_WARNING_LENGTH: float = 6.0
const LANE_WARNING_GAP: float = 1.3
const LANE_WARNING_WIDTH: float = 1.45
const LANE_WARNING_OPACITY: float = 0.62
## Warm earthy orange every lane warning is pulled toward (ochre paint).
const LANE_WARNING_COLOR: Color = Color(0.92, 0.5, 0.14)

# --- Contact shadow ----------------------------------------------------------------------------
## Blob shadow under the runner (kept with the real sun shadows: it grounds the jump height).
## Size (x = across, y = along the track), opacity and lift above the path.
const SHADOW_SIZE: Vector2 = Vector2(1.05, 1.25)
const SHADOW_OPACITY: float = 0.45
const SHADOW_LIFT: float = 0.06
## Shadow shrink per metre of height while jumping, and its minimum scale.
const SHADOW_SHRINK_PER_M: float = 0.16
const SHADOW_MIN_SCALE: float = 0.45

# --- Atmosphere (each one can be switched off if it costs too much on a phone) ----------------
## The day sky dome (gradient, sun, clouds, far silhouettes, pterosaurs). Off = a flat colour.
const FEATURE_SKY_DOME: bool = true
## Legacy name of FEATURE_SKY_DOME.
const FEATURE_NIGHT_SKY: bool = FEATURE_SKY_DOME
## Sky details: cloud cover multiplier and the pterosaurs gliding far away (0 = none).
const SKY_CLOUDS: float = 1.0
const SKY_PTEROSAURS: float = 1.0
## Legacy (night sky): no longer used.
const SKY_STARS: float = 0.0
const SKY_MOON: float = 0.0
const SKY_SKYLINE: float = 0.0
## Legacy (neon windows): retired with the buildings.
const FEATURE_WINDOW_FLICKER: bool = false
const WINDOW_FLICKER_RATIO: float = 0.0
const WINDOW_FLICKER_SPEED: float = 0.0
## Wind sway of the vegetation (metres at the tips) and its speed.
const WIND_SWAY: float = 0.14
const WIND_SPEED: float = 1.35
## Particles kicked up under the runner's feet (player.gd; the old "rail sparks" names).
const FEATURE_RAIL_SPARKS: bool = true
const RAIL_SPARK_AMOUNT: int = 10
## Motion trails blend softly over the bright world (0 = alpha, 1 = additive light).
const TRAIL_ADDITIVE: float = 0.15
## Caves and bridges: chance that a recycled chunk starts one, and how many chunks it lasts.
const FEATURE_TUNNELS_BRIDGES: bool = true
const TRACK_FEATURE_CHANCE: float = 0.12
const TRACK_FEATURE_MIN_CHUNKS: int = 2
const TRACK_FEATURE_MAX_CHUNKS: int = 4
