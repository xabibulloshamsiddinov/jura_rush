## Every hand-tuned look value of the run in one place: bloom, coins, player readability,
## obstacle warnings and the contact shadow. Change a number here and re-run; nothing else has to
## be touched. Feature flags (FEATURE_*) switch a whole effect off if it costs too much on a phone.
class_name VisualTuning
extends RefCounted

# --- Glow / bloom (WorldEnvironment, applied by BiomeDirector) ---------------------------------
## Overall glow strength. Was 0.9: neon and coins turned into white blobs.
const GLOW_INTENSITY: float = 0.55
## How much the glow spreads. Kept low so the halo stays tight around neon strips.
const GLOW_STRENGTH: float = 0.85
## Bloom adds glow to EVERYTHING, not only bright pixels. 0 = only HDR-bright pixels glow.
const GLOW_BLOOM: float = 0.0
## Only pixels brighter than this glow. Coins are capped below it (see COIN_MAX_BRIGHTNESS),
## so yellow stays yellow; neon emission (energy ~2) still crosses it.
const GLOW_HDR_THRESHOLD: float = 1.15
## Scale applied to the HDR part above the threshold.
const GLOW_HDR_SCALE: float = 1.6
## SCREEN keeps colours saturated; ADDITIVE (old value) blows highlights out to white.
const GLOW_BLEND_MODE: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_SCREEN
## Tonemapper white point. Higher = brights roll off later (less washing out to white).
const TONEMAP_WHITE: float = 6.0

# --- Coins -------------------------------------------------------------------------------------
## Disc radius / thickness in metres (old: 0.34 / 0.08, now about 60 %).
const COIN_RADIUS: float = 0.21
const COIN_THICKNESS: float = 0.05
## Coins shrink to nothing between these two distances from the camera (metres), so a coin can
## never fill the screen.
const COIN_NEAR_FADE_START: float = 4.5
const COIN_NEAR_FADE_END: float = 2.0
## A coin is removed once it is this far behind the player (metres, +Z). Must stay above the
## pickup window (PickupSystem.COLLECT_Z = 0.9) or coins would vanish before being collected.
const COIN_BEHIND_KILL_Z: float = 1.6
## Brightness cap of the coin colour, kept under GLOW_HDR_THRESHOLD.
const COIN_MAX_BRIGHTNESS: float = 1.05

# --- Player readability ------------------------------------------------------------------------
const FEATURE_PLAYER_RIM: bool = true
## Rim light colour and strength on the runner's silhouette (view-angle based, no extra pass).
const PLAYER_RIM_COLOR: Color = Color(0.75, 0.95, 1.0)
const PLAYER_RIM_STRENGTH: float = 0.85
## Higher = thinner rim.
const PLAYER_RIM_POWER: float = 2.6
## Obstacles whose far edge is this many metres behind the player are hidden, so passed
## barriers never stand between the camera and the runner.
const HIDE_PASSED_OBSTACLES_Z: float = 1.0

# --- Obstacle warning --------------------------------------------------------------------------
## Fog starts this far away (was 60 m): obstacles read clearly from further out.
const FOG_START: float = 85.0
## Emissive warning stripes keep this share of their light inside the fog (0 = fog hides them).
const WARNING_FOG_PIERCE: float = 0.65
## Pulsing glow on barrier warning stripes.
const WARNING_PULSE_SPEED: float = 5.0
const WARNING_PULSE_AMOUNT: float = 0.35
## Faint marker painted on the rails in front of a barrier.
const FEATURE_LANE_WARNING: bool = true
const LANE_WARNING_LENGTH: float = 7.0
const LANE_WARNING_GAP: float = 1.5
const LANE_WARNING_WIDTH: float = 1.5
const LANE_WARNING_OPACITY: float = 0.32

# --- Contact shadow ----------------------------------------------------------------------------
## Blob shadow size (x = across, y = along the track), opacity and lift above the rails.
const SHADOW_SIZE: Vector2 = Vector2(1.05, 1.25)
const SHADOW_OPACITY: float = 0.6
const SHADOW_LIFT: float = 0.02
## Shadow shrink per metre of height while jumping, and its minimum scale.
const SHADOW_SHRINK_PER_M: float = 0.16
const SHADOW_MIN_SCALE: float = 0.45
