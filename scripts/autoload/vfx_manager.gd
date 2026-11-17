## VFX service. play(id, position) spawns a pooled one-shot effect and returns it to the pool
## when finished; screen effects go through ScreenFx. Subscribes to the event bus so gameplay
## never triggers effects directly. Honours the quality preset and "reduce effects".
extends Node

const MESH_FX_COUNT: int = 6

var screen: ScreenFx = null

var _container: Node3D = null
var _active_nodes: Array[Node3D] = []
var _active_ids: Array[StringName] = []
var _active_left: Array[float] = []
var _mesh_nodes: Array[MeshInstance3D] = []
var _mesh_materials: Array[ShaderMaterial] = []
var _mesh_time: Array[float] = []
var _mesh_duration: Array[float] = []
var _mesh_from: Array[Vector3] = []
var _mesh_to: Array[Vector3] = []
var _mesh_color: Array[Color] = []
var _ring_mesh: TorusMesh = null
var _dust_timer: float = 0.0
var _running: bool = false
var _dashing: bool = false
var _speed_fraction: float = 0.0
var _cfg: GameConfig = GameConfig.current()


func _ready() -> void:
	Services.provide(&"vfx", self)
	_container = Node3D.new()
	add_child(_container)
	screen = ScreenFx.new()
	add_child(screen)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.82
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4
	for i in range(MESH_FX_COUNT):
		var material: ShaderMaterial = Mats.glow(Color.WHITE, 2.0, 0.0, 0.0, true)
		var node: MeshInstance3D = MeshLib.mi(_ring_mesh, material)
		node.visible = false
		_container.add_child(node)
		_mesh_nodes.append(node)
		_mesh_materials.append(material)
		_mesh_time.append(0.0)
		_mesh_duration.append(0.0)
		_mesh_from.append(Vector3.ONE)
		_mesh_to.append(Vector3.ONE)
		_mesh_color.append(Color.WHITE)
	_connect_events()


## Creates the effect pools (fixed size: when all instances of an effect are busy, extra
## requests are simply dropped). Called from the boot sequence.
func prewarm() -> void:
	for id: StringName in VfxFactory.POOL_SIZES.keys():
		PoolManager.register_factory(_pool_id(id), VfxFactory.build.bind(id), int(VfxFactory.POOL_SIZES[id]), false)


## Plays a pooled one-shot world effect.
func play(id: StringName, position: Vector3, color: Color = Color.WHITE) -> void:
	var pool: StringName = _pool_id(id)
	if not PoolManager.has_pool(pool):
		return
	var node: CPUParticles3D = PoolManager.acquire(pool) as CPUParticles3D
	if node == null:
		return
	_container.add_child(node)
	node.position = position
	if color != Color.WHITE:
		node.color = color
	node.restart()
	# Compound effects (egg sparkle + warm burst, dust puff + pebbles) carry child emitters.
	for child: Node in node.get_children():
		var sub: CPUParticles3D = child as CPUParticles3D
		if sub != null:
			sub.restart()
	_active_nodes.append(node)
	_active_ids.append(pool)
	_active_left.append(float(VfxFactory.LIFETIMES.get(id, 1.0)) + 0.1)


## Expanding ring (shockwave, shield ripple). additive: 1 = light (old glow), 0 = soft dusty
## alpha ring that reads in daylight.
func ring(position: Vector3, color: Color, from_radius: float, to_radius: float, duration: float,
		flat: bool = true, additive: float = 0.35) -> void:
	var i: int = _free_mesh_slot()
	var node: MeshInstance3D = _mesh_nodes[i]
	node.mesh = _ring_mesh
	node.position = position
	node.rotation = Vector3.ZERO if flat else Vector3(PI * 0.5, 0.0, 0.0)
	_start_mesh(i, color, Vector3.ONE * from_radius, Vector3.ONE * to_radius, duration, additive)


## Stretched wind streak along the track (near-miss whoosh). Subtle: soft alpha, pale.
func streak(position: Vector3, color: Color, length: float, duration: float) -> void:
	var i: int = _free_mesh_slot()
	var node: MeshInstance3D = _mesh_nodes[i]
	node.mesh = MeshLib.box()
	node.position = position
	node.rotation = Vector3.ZERO
	_start_mesh(i, color, Vector3(0.05, 1.4, length * 0.3), Vector3(0.015, 1.0, length), duration, 0.2)


## Plays a UI-space effect at a screen position (base resolution pixels).
func play_ui(id: StringName, screen_position: Vector2) -> void:
	if id != &"confetti":
		return
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = screen_position
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(int(60.0 * SettingsManager.particle_scale()), 8)
	p.lifetime = 1.8
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 500.0
	p.initial_velocity_max = 1200.0
	p.gravity = Vector2(0.0, 1400.0)
	p.scale_amount_min = 8.0
	p.scale_amount_max = 18.0
	p.hue_variation_min = -1.0
	p.hue_variation_max = 1.0
	p.color = Color(0.2, 0.9, 1.0)
	p.finished.connect(p.queue_free)
	screen.add_child(p)
	p.emitting = true


func _process(delta: float) -> void:
	for i in range(_active_nodes.size() - 1, -1, -1):
		_active_left[i] -= delta
		if _active_left[i] <= 0.0:
			PoolManager.release(_active_ids[i], _active_nodes[i])
			_active_nodes.remove_at(i)
			_active_ids.remove_at(i)
			_active_left.remove_at(i)
	for i in range(MESH_FX_COUNT):
		if not _mesh_nodes[i].visible:
			continue
		_mesh_time[i] += delta
		var t: float = minf(_mesh_time[i] / _mesh_duration[i], 1.0)
		_mesh_nodes[i].scale = _mesh_from[i].lerp(_mesh_to[i], MathUtils.ease_out_cubic(t))
		_mesh_materials[i].set_shader_parameter(&"albedo", Color(_mesh_color[i], 1.0 - t))
		if t >= 1.0:
			_mesh_nodes[i].visible = false
	if _running:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.22
			var player: Node3D = _player()
			if player != null and bool(player.get(&"on_ground")) and not bool(player.get(&"flying")):
				play(&"dust", player.position + Vector3(0.0, 0.08, 0.3))


func _pool_id(id: StringName) -> StringName:
	return StringName("vfx_" + String(id))


func _free_mesh_slot() -> int:
	var oldest: int = 0
	for i in range(MESH_FX_COUNT):
		if not _mesh_nodes[i].visible:
			return i
		if _mesh_time[i] > _mesh_time[oldest]:
			oldest = i
	return oldest


func _start_mesh(i: int, color: Color, from: Vector3, to: Vector3, duration: float,
		additive: float = 0.35) -> void:
	_mesh_time[i] = 0.0
	_mesh_duration[i] = maxf(duration, 0.05)
	_mesh_from[i] = from
	_mesh_to[i] = to
	_mesh_color[i] = color
	_mesh_nodes[i].scale = from
	_mesh_nodes[i].visible = true
	_mesh_materials[i].set_shader_parameter(&"albedo", color)
	_mesh_materials[i].set_shader_parameter(&"additive", additive)


func _player() -> Node3D:
	var world: Object = Services.locate(&"world")
	if world == null:
		return null
	return world.get(&"player") as Node3D


func _player_pos() -> Vector3:
	var player: Node3D = _player()
	return player.position if player != null else Vector3.ZERO


func _strength() -> float:
	return 0.35 if SettingsManager.reduce_effects() else 1.0


func _update_speed_lines() -> void:
	var amount: float = smoothstep(0.3, 1.0, _speed_fraction) * 0.7
	if _dashing:
		amount = 1.0
	screen.set_speed_lines(amount * _strength() if _running else 0.0)


func _connect_events() -> void:
	GameEvents.coin_collected.connect(func(_value: int, pos: Vector3) -> void:
		play(&"coin_pickup", pos))
	GameEvents.player_landed.connect(func(impact: float) -> void:
		if impact > 9.0:
			play(&"land", _player_pos() + Vector3(0.0, 0.1, 0.0)))
	GameEvents.lane_changed.connect(func(_from: int, _to: int) -> void:
		var player: Node3D = _player()
		if player != null and bool(player.get(&"on_ground")):
			play(&"sparks", player.position + Vector3(0.0, 0.1, 0.0)))
	GameEvents.player_stumbled.connect(func(_kind: StringName) -> void:
		play(&"sparks", _player_pos() + Vector3(0.0, 1.0, -0.3))
		screen.danger_edge(0.7 * _strength()))
	GameEvents.player_crashed.connect(_on_crash)
	GameEvents.near_miss.connect(func(lane: int) -> void:
		var pos: Vector3 = _player_pos()
		var side: float = signf(_cfg.lane_x(lane) - pos.x)
		streak(Vector3(pos.x + side * 0.9, 1.2, -2.0), Color(0.96, 0.93, 0.85, 0.7), 7.0, 0.3))
	GameEvents.shield_hit.connect(func() -> void:
		ring(_player_pos() + Vector3(0.0, 1.0, 0.0), Color(0.55, 0.85, 0.8), 0.8, 2.4, 0.35, false, 0.5))
	GameEvents.shield_broken.connect(func() -> void:
		play(&"shards", _player_pos() + Vector3(0.0, 1.0, 0.0)))
	GameEvents.powerup_activated.connect(func(id: StringName, _d: float) -> void:
		var def: PowerupDef = ContentDB.powerup(id)
		var color: Color = def.color if def != null else Color.WHITE
		play(&"burst", _player_pos() + Vector3(0.0, 1.0, 0.0), Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.85))
		ring(_player_pos() + Vector3(0.0, 0.1, 0.0), color, 0.5, 3.0, 0.45)
		if id == &"dash":
			_dashing = true
			_update_speed_lines())
	GameEvents.powerup_expired.connect(func(id: StringName) -> void:
		if id == &"dash":
			_dashing = false
			_update_speed_lines())
	GameEvents.obstacle_smashed.connect(func(pos: Vector3) -> void:
		play(&"debris", pos)
		ring(pos, Color(0.78, 0.64, 0.46), 0.4, 2.6, 0.35, false, 0.0))
	GameEvents.mystery_box_opened.connect(func(_reward: StringName, _amount: int) -> void:
		play(&"burst", _player_pos() + Vector3(0.0, 1.2, -0.5), Color(1.5, 1.05, 0.45, 0.9))
		ring(_player_pos() + Vector3(0.0, 1.2, 0.0), Color(0.95, 0.68, 0.3), 0.3, 2.2, 0.4, false, 0.4))
	GameEvents.biome_changed.connect(func(_id: StringName, _title: String) -> void:
		screen.flash(Color(1.0, 0.95, 0.82), 0.22 * _strength(), 0.9))
	GameEvents.speed_changed.connect(func(speed: float) -> void:
		_speed_fraction = _cfg.speed_fraction(speed)
		_update_speed_lines())
	GameEvents.state_changed.connect(func(_from: StringName, to: StringName) -> void:
		_running = to == &"running"
		if to != &"running":
			_dashing = false
		_update_speed_lines())


func _on_crash(_kind: StringName) -> void:
	crash_burst(_player_pos() + Vector3(0.0, 1.0, 0.0))


## Crash at a world position: a dust cloud with rock debris, a dusty shock ring, a soft warm flash,
## the danger edge and a light chromatic pulse.
func crash_burst(pos: Vector3) -> void:
	play(&"crash", pos)
	play(&"debris", pos)
	ring(pos - Vector3(0.0, 0.9, 0.0), Color(0.8, 0.66, 0.48), 0.5, 4.5, 0.55, true, 0.0)
	screen.flash(Color(1.0, 0.9, 0.75), 0.45 * _strength(), 0.14)
	screen.danger_edge(1.0 * _strength())
	if SettingsManager.quality() > 0 and not SettingsManager.reduce_effects():
		screen.chroma_pulse(0.5)
