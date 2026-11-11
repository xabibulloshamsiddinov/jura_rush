## Player-vs-obstacle collision and near-miss detection.
##
## Instead of physics bodies this is a deterministic swept box test: each step the obstacle box
## is extended by the distance the world moved, so thin barriers cannot tunnel at any speed and
## the result is identical on every device (and in headless bot tests).
## Near miss: an obstacle that overlapped the player's box grown by near_miss_margin, never hit,
## and has now fully passed.
class_name CollisionSystem
extends Node

const PLAYER_HALF_DEPTH: float = 0.3
const SCAN_AHEAD: float = 24.0
const SCAN_BEHIND: float = 8.0

var track: TrackManager = null
var player: Player = null

var _cfg: GameConfig = GameConfig.current()


## Tests the player against every obstacle near z = 0. `step` = metres the world just moved.
func tick(step: float) -> void:
	if player.is_dead:
		return
	var px: float = player.position.x
	var feet: float = player.feet_y
	var top: float = feet + player.body_height()
	var half_w: float = _cfg.player_half_width
	var margin: float = _cfg.near_miss_margin
	var chunk_length: float = _cfg.chunk_length
	for chunk in track.chunks:
		var near_edge: float = chunk.position.z
		if near_edge < -SCAN_AHEAD:
			break
		if near_edge - chunk_length > SCAN_BEHIND + SCAN_AHEAD:
			continue
		for o in chunk.obstacles:
			if o.disabled:
				continue
			var cz: float = near_edge + o.position.z
			var z_far: float = cz - o.length * 0.5 - step
			var z_near: float = cz + o.length * 0.5
			if z_far > PLAYER_HALF_DEPTH + 0.2:
				# Fully behind the player now.
				if o.near_flag and not o.ghost:
					o.near_flag = false
					o.ghost = true
					GameEvents.near_miss.emit(o.lane)
				continue
			if z_near < -PLAYER_HALF_DEPTH or o.ghost:
				continue
			var dx: float = absf(px - o.position.x)
			var reach: float = half_w + o.half_width
			if dx >= reach + margin:
				continue
			var dz: float = -cz
			if dx < reach and o.blocks(feet, top, dz, _cfg.step_height):
				if player.smashes_obstacles():
					o.smash()
					continue
				# Side hit: sliding into something that is already alongside the runner.
				var side: bool = player.is_changing_lane() and z_near > 0.6
				o.on_player_hit(player, side)
				if player.is_dead:
					return
			elif not player.is_invulnerable() \
					and o.blocks(feet - margin, top + margin, dz, _cfg.step_height + margin):
				o.near_flag = true
