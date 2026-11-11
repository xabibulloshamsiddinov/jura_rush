## Collects coins and pickups with one distance sweep per step (no per-coin Area3D), and pulls
## coins toward the player while the magnet is active (ease-in attraction).
class_name PickupSystem
extends Node

const COLLECT_X: float = 0.85
const COLLECT_Z: float = 0.9
const SCAN: float = 12.0

var track: TrackManager = null
var player: Player = null
var sky_coins: SkyCoinTrail = null

var _cfg: GameConfig = GameConfig.current()


## Sweeps coins and pickups around the player. `step` = metres the world just moved.
func tick(delta: float, step: float) -> void:
	var reach: float = SCAN
	if player.magnet.active:
		reach = maxf(SCAN, player.magnet.radius + 2.0)
	var chunk_length: float = _cfg.chunk_length
	for chunk in track.chunks:
		var near_edge: float = chunk.position.z
		if near_edge < -reach:
			break
		for p in chunk.pickups:
			p.tick(delta)
		if near_edge - chunk_length > reach:
			continue
		if chunk.coins.count > 0:
			_sweep_field(chunk.coins, near_edge, delta, step)
		for p in chunk.pickups:
			if p.collected:
				continue
			var pz: float = near_edge + p.position.z
			if pz - step > COLLECT_Z or pz < -COLLECT_Z:
				continue
			if absf(p.position.x - player.position.x) < p.radius \
					and p.position.y > player.feet_y - 0.6 and p.position.y < player.feet_y + 2.6:
				p.collect(player)
	if sky_coins != null and sky_coins.field.count > 0:
		sky_coins.advance(step)
		_sweep_field(sky_coins.field, sky_coins.field.position.z, delta, step)


func _sweep_field(field: CoinField, field_z: float, delta: float, step: float) -> void:
	var px: float = player.position.x
	var feet: float = player.feet_y
	var body_mid: float = feet + player.body_height() * 0.5
	var y_low: float = feet - 0.35
	var y_high: float = feet + player.body_height() + 0.45
	var magnet_on: bool = player.magnet.active and not player.is_dead
	var radius_sq: float = player.magnet.radius * player.magnet.radius
	var local_player: Vector3 = Vector3(px, body_mid, -field_z)
	for i in range(field.count):
		var state: int = field.states[i]
		if state == CoinField.DEAD:
			continue
		var pos: Vector3 = field.positions[i]
		var wz: float = field_z + pos.z
		# Gone once it is behind the runner: a coin between the player and the camera would
		# otherwise fill the screen.
		if wz > VisualTuning.COIN_BEHIND_KILL_Z:
			field.kill(i)
			continue
		if magnet_on and state == CoinField.ALIVE and absf(wz) < player.magnet.radius:
			var ddx: float = pos.x - px
			var ddy: float = pos.y - body_mid
			if ddx * ddx + ddy * ddy + wz * wz < radius_sq:
				field.states[i] = CoinField.PULLED
				state = CoinField.PULLED
		if state == CoinField.PULLED:
			# Ease-in: pull speed grows the longer the coin has been attracted.
			field.pull_time[i] += delta
			var pull_speed: float = 6.0 + field.pull_time[i] * field.pull_time[i] * 220.0
			pos = pos.move_toward(local_player, pull_speed * delta)
			field.move(i, pos)
			wz = field_z + pos.z
		if wz - step <= COLLECT_Z and wz >= -COLLECT_Z and absf(pos.x - px) < COLLECT_X \
				and pos.y > y_low and pos.y < y_high and not player.is_dead:
			field.kill(i)
			GameEvents.coin_collected.emit(_cfg.coin_value, Vector3(pos.x, pos.y, wz))
