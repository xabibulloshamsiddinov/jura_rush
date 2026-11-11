## Tunables and content for the 2 Player versus mode ("Neon Pursuit"): two cars on a 5-lane
## highway, police closing in from behind, combat power-ups picked up from the road.
## Coordinates: forward = -Z. The cars stay near z = 0 (treadmill); the road moves toward +Z.
class_name VsDefs
extends RefCounted

const TITLE: String = "NEON PURSUIT"

# --- Road ------------------------------------------------------------------
const LANES: int = 5
const LANE_W: float = 3.4
const ROAD_HALF: float = LANE_W * 2.5 + 0.9

# --- Match -----------------------------------------------------------------
const MATCH_TIME: float = 180.0
const LIVES: int = 3
const MAX_HEALTH: float = 100.0
const SLOTS: int = 3
const COUNTDOWN_STEP: float = 0.8
const RESPAWN_TIME: float = 2.0
const RESPAWN_GHOST: float = 2.5

# --- Speeds (m/s) ------------------------------------------------------------
const START_SPEED: float = 34.0
const MAX_SPEED: float = 56.0
const RAMP_TIME: float = 150.0
## Relative speed (toward -Z) a car reaches on gas / brake / when coasting.
const GAS_REL: float = 8.0
const BRAKE_REL: float = -11.0
const COAST_REL: float = -1.2
const NITRO_REL: float = 26.0
const REL_ACCEL: float = 3.5
const LANE_TIME: float = 0.2

# --- Positions relative to the treadmill anchor ----------------------------------
const FRONT_Z: float = -17.0
const SPAWN_Z: float = -6.0
## The cruiser tails its car at this gap (shrinks over the match) ...
const POLICE_GAP_START: float = 9.5
const POLICE_GAP_END: float = 6.0
## ... but can only close in / fall back this fast (m/s), so hits and braking let it catch up.
const POLICE_FORWARD_RATE: float = 7.5
const POLICE_BACK_RATE: float = 3.5
const POLICE_RESET_GAP: float = 15.0
## The car is "in reach" when the police car is closer than this behind it.
const BUST_RANGE: float = 3.6
const BUST_TIME: float = 1.6

# --- Car body ---------------------------------------------------------------
const CAR_HALF_W: float = 0.95
const CAR_HALF_L: float = 2.2

# --- Spawning (metres of road between rows) -----------------------------------
const TRAFFIC_GAP_START: float = 30.0
const TRAFFIC_GAP_END: float = 15.0
const ORB_GAP: float = 85.0
const SPAWN_Z_FAR: float = -175.0
const DESPAWN_Z: float = 32.0

# --- Player look -------------------------------------------------------------
const PLAYER_COLORS: Array[Color] = [Color(1.0, 0.42, 0.08), Color(0.1, 0.72, 1.0)]
const PLAYER_GLOW: Array[Color] = [Color(1.0, 0.3, 0.05), Color(0.0, 0.55, 1.0)]

# --- Power-ups -----------------------------------------------------------------
## Original names; the mechanics follow classic combat racers:
##   seeker = homing rocket, bolt = 3 straight shots, pulse = radial shockwave,
##   emp = domes dropped in front of the rival, mine = dropped behind,
##   nitro = boost (backwards: hard brake), shield = timed protection, repair = health.
const POWERUPS: Array[StringName] = [&"seeker", &"bolt", &"pulse", &"emp", &"mine", &"nitro",
		&"shield", &"repair"]
const COLORS: Dictionary = {
	&"seeker": Color(1.0, 0.16, 0.2),
	&"bolt": Color(0.78, 0.3, 1.0),
	&"pulse": Color(1.0, 0.36, 0.78),
	&"emp": Color(0.25, 0.92, 1.0),
	&"mine": Color(1.0, 0.56, 0.08),
	&"nitro": Color(0.3, 1.0, 0.35),
	&"shield": Color(0.3, 0.52, 1.0),
	&"repair": Color(1.0, 0.9, 0.2),
}
const WEIGHTS: Dictionary = {
	&"seeker": 16, &"bolt": 16, &"pulse": 12, &"emp": 9, &"mine": 14, &"nitro": 14,
	&"shield": 10, &"repair": 9,
}
## Power-ups that can be fired backwards (hold brake while firing).
const REVERSIBLE: Array[StringName] = [&"seeker", &"bolt", &"nitro"]

# --- Damage --------------------------------------------------------------------
const DMG_SEEKER: float = 34.0
const DMG_BOLT: float = 12.0
const DMG_PULSE: float = 22.0
const DMG_EMP: float = 16.0
const DMG_MINE: float = 30.0
const DMG_TRAFFIC: float = 18.0
const DMG_RAM: float = 5.0
const REPAIR_AMOUNT: float = 45.0
const SHIELD_TIME: float = 6.0
const NITRO_TIME: float = 2.2
const BRAKE_JUMP_TIME: float = 0.45
const EMP_JAM: float = 0.9
const PULSE_RADIUS: float = 7.5

# --- Fans (score) ---------------------------------------------------------------
const FANS_HIT: int = 150
const FANS_WRECK: int = 1000
const FANS_SMASH: int = 60
const FANS_NEAR: int = 25
const FANS_BLOCK: int = 200
const FANS_PICKUP: int = 10


## X of a lane centre; lane 0 is the left-most.
static func lane_x(lane: int) -> float:
	return (float(lane) - float(LANES - 1) * 0.5) * LANE_W


## Nearest lane to an x coordinate.
static func lane_at(x: float) -> int:
	return clampi(roundi(x / LANE_W + float(LANES - 1) * 0.5), 0, LANES - 1)


## Colour of a power-up id.
static func color(id: StringName) -> Color:
	return COLORS.get(id, Color.WHITE) as Color


## Translated display name of a power-up.
static func title(id: StringName) -> String:
	return Tr.t(StringName("vs.pu." + String(id)))


## Weighted random power-up id.
static func random_powerup(rng: RandomNumberGenerator) -> StringName:
	var total: int = 0
	for id: StringName in POWERUPS:
		total += int(WEIGHTS[id])
	var roll: int = rng.randi_range(1, total)
	for id: StringName in POWERUPS:
		roll -= int(WEIGHTS[id])
		if roll <= 0:
			return id
	return POWERUPS[0]
