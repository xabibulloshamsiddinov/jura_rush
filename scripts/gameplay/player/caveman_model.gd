## The caveman's body: joint layout, one cached mesh per bone (built once with CavemanMesh and
## shared by every PlayerVisual and every skin), hair styles, accessories and the per-skin
## material. Skins never rebuild geometry: colours and fur patterns live in the material.
##
## Space: metres, feet at y = 0, facing -Z. Every bone mesh hangs along -Y from its pivot.
class_name CavemanModel
extends RefCounted

const SHADER: Shader = preload("res://assets/shaders/character_toon.gdshader")
const S := CavemanMesh.Slot

# --- Joint layout (bulk 1, height_scale 1) ------------------------------------------------------
const HIP_Y: float = 0.80
const HIP_X: float = 0.115
const THIGH: float = 0.36
const SHIN: float = 0.35
const ANKLE_Y: float = 0.09
const SPINE_Y: float = 0.06
const NECK: Vector3 = Vector3(0.0, 0.50, 0.0)
const SHOULDER: Vector3 = Vector3(0.258, 0.42, 0.0)
const UPPER_ARM: float = 0.30
const FOREARM: float = 0.25
## Head centre relative to the neck pivot.
const HEAD_C: Vector3 = Vector3(0.0, 0.215, -0.02)
const HEAD_R: Vector3 = Vector3(0.19, 0.205, 0.195)
## Secondary-motion pivots (head space).
const HAIR_PIVOT: Vector3 = Vector3(0.0, 0.29, 0.13)
const BEARD_PIVOT: Vector3 = Vector3(0.0, 0.10, -0.10)
const FEATHER_PIVOT: Vector3 = Vector3(0.13, 0.36, 0.12)
## Skirt (tunic lower half) pivot, hips space.
const HEM_PIVOT: Vector3 = Vector3(0.0, 0.08, 0.0)

const BONE_COLOR: Color = Color(0.94, 0.89, 0.76)
const EYE_WHITE: Color = Color(0.98, 0.97, 0.94)
const PUPIL: Color = Color(0.10, 0.07, 0.05)
const STONE: Color = Color(0.56, 0.55, 0.52)
const MOUTH: Color = Color(0.36, 0.10, 0.08)

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## Cached mesh of one body part. Known names: head, lids, chest, hips, skirt, thigh, shin,
## foot_l, foot_r, upper_arm_l, upper_arm_r, forearm_l, forearm_r, beard,
## hair_cap_<style>, hair_locks_<style>, acc_<kind>_<part>.
static func mesh(part: StringName) -> ArrayMesh:
	if _meshes.has(part):
		return _meshes[part] as ArrayMesh
	var built: ArrayMesh = _build(part)
	_meshes[part] = built
	return built


## Triangle count of a part (budget checks in the lab).
static func triangles(part: StringName) -> int:
	var m: ArrayMesh = mesh(part)
	if m.get_surface_count() == 0:
		return 0
	var arrays: Array = m.surface_get_arrays(0)
	@warning_ignore("integer_division")
	return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


## The material of a skin (cached per skin).
static func material(def: CharacterDef) -> ShaderMaterial:
	var key: String = "%s|%s|%s|%s|%s|%s|%s|%s|%.2f" % [def.id, def.head_color.to_html(), def.body_color.to_html(),
			def.hair_color.to_html(), def.leather_color.to_html(), def.glow_color.to_html(),
			def.limb_color.to_html(), def.fur_pattern, def.pattern_scale]
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	var blush: Color = def.head_color.lerp(Color(0.95, 0.42, 0.38), 0.4)
	mat.set_shader_parameter(&"palette", PackedColorArray([def.head_color, def.body_color, def.hair_color,
			def.leather_color, BONE_COLOR, EYE_WHITE, PUPIL, def.glow_color, def.limb_color, STONE, MOUTH, blush]))
	mat.set_shader_parameter(&"pattern_kind", pattern_index(def.fur_pattern))
	mat.set_shader_parameter(&"pattern_scale", def.pattern_scale)
	apply_rim(mat)
	_materials[key] = mat
	return mat


## Readability rim of the character shader (caveman and pterosaur), from VisualTuning.PLAYER_RIM_*.
static func apply_rim(mat: ShaderMaterial) -> void:
	var on: bool = VisualTuning.FEATURE_PLAYER_RIM
	mat.set_shader_parameter(&"rim_color", VisualTuning.PLAYER_RIM_COLOR)
	mat.set_shader_parameter(&"rim_strength", VisualTuning.PLAYER_RIM_STRENGTH if on else 0.0)
	mat.set_shader_parameter(&"rim_power", VisualTuning.PLAYER_RIM_POWER)


static func pattern_index(pattern: StringName) -> int:
	match pattern:
		&"spots":
			return 1
		&"stripes":
			return 2
		&"leaves":
			return 3
		&"patches":
			return 4
	return 0


static func _build(part: StringName) -> ArrayMesh:
	var name: String = String(part)
	if name.begins_with("hair_cap_"):
		return _hair_cap(StringName(name.trim_prefix("hair_cap_")))
	if name.begins_with("hair_locks_"):
		return _hair_locks(StringName(name.trim_prefix("hair_locks_")))
	if name.begins_with("acc_"):
		return _accessory_part(StringName(name.trim_prefix("acc_")))
	match part:
		&"head":
			return _head()
		&"lids":
			return _lids()
		&"beard":
			return _beard()
		&"chest":
			return _chest()
		&"hips":
			return _hips()
		&"skirt":
			return _skirt()
		&"thigh":
			return _thigh()
		&"shin":
			return _shin()
		&"foot_l":
			return _foot(-1.0)
		&"foot_r":
			return _foot(1.0)
		&"upper_arm_l":
			return _upper_arm(-1.0)
		&"upper_arm_r":
			return _upper_arm(1.0)
		&"forearm_l":
			return _forearm(-1.0)
		&"forearm_r":
			return _forearm(1.0)
	push_warning("CavemanModel: unknown part %s" % name)
	return ArrayMesh.new()


# --- Helpers -------------------------------------------------------------------------------------

## 0..1 tooth wave with sharp tips (ragged hems, fringes).
static func _spikes(x: float) -> float:
	var f: float = fposmod(x, 1.0)
	var tri: float = 1.0 - absf(f - 0.5) * 2.0
	return tri * tri


static func _pts(values: Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for v: Variant in values:
		out.append(v as Vector3)
	return out


static func _radii(values: Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for v: Variant in values:
		out.append(float(v))
	return out


## Soft occlusion blob: 1 - strength * exp(-|p - centre|^2 / r^2).
static func _occ(p: Vector3, centre: Vector3, r: float, strength: float) -> float:
	return 1.0 - strength * exp(-(p - centre).length_squared() / (r * r))


# --- Head ----------------------------------------------------------------------------------------

static func _head() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var c: Vector3 = HEAD_C
	var r: Vector3 = HEAD_R
	# Skull and face: the jaw widens and pushes forward, the forehead slopes back a little.
	m.style(S.SKIN)
	m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
		var d: Vector3 = (p - c) / r
		var jaw: float = smoothstep(0.15, -0.8, d.y)
		d.x *= 1.0 + 0.11 * jaw
		if d.z < 0.0:
			d.z *= 1.0 + 0.12 * jaw - 0.08 * smoothstep(0.35, 0.95, d.y)
		else:
			d.z *= 1.0 + 0.05 * smoothstep(0.0, 0.8, d.y)
		return c + d * r
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		var eyes: float = minf(_occ(p, c + Vector3(-0.075, 0.01, -0.17), 0.06, 0.35),
				_occ(p, c + Vector3(0.075, 0.01, -0.17), 0.06, 0.35))
		var under_jaw: float = 1.0 - 0.3 * smoothstep(-0.12, -0.21, p.y - c.y)
		var under_nose: float = _occ(p, c + Vector3(0.0, -0.09, -0.2), 0.05, 0.25)
		return eyes * under_jaw * under_nose
	m.ellipsoid(c, r, 12, 8)
	# Heavy brow ridge.
	m.style(S.SKIN, 1.0)
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return 1.0 - 0.25 * smoothstep(c.y + 0.07, c.y + 0.03, p.y)
	m.cap_rings = 1
	m.tube(_pts([c + Vector3(-0.15, 0.045, -0.11), c + Vector3(-0.07, 0.07, -0.162),
			c + Vector3(0.07, 0.07, -0.162), c + Vector3(0.15, 0.045, -0.11)]),
			_radii([0.022, 0.031, 0.031, 0.022]), 5, true, true, Vector2(1.0, 0.85))
	# Bushy eyebrows sitting on the ridge, slightly raised at the outer end (friendly).
	for s: float in [-1.0, 1.0]:
		m.style(S.HAIR, 0.9)
		m.cap_rings = 1
		m.tube(_pts([c + Vector3(s * 0.025, 0.103, -0.198), c + Vector3(s * 0.085, 0.113, -0.19),
				c + Vector3(s * 0.135, 0.105, -0.155)]), _radii([0.019, 0.025, 0.016]), 4, true, true,
				Vector2(1.0, 0.6))
	# Eyes: whites tucked under the brow, dark pupils with a glint (gloss).
	for s: float in [-1.0, 1.0]:
		m.style(S.EYE_WHITE, 0.95, 0.0, 0.6)
		m.ellipsoid(c + Vector3(s * 0.074, 0.012, -0.163), Vector3(0.047, 0.055, 0.036), 8, 5)
		m.style(S.PUPIL, 1.0, 0.0, 1.0)
		m.ellipsoid(c + Vector3(s * 0.066, 0.008, -0.193), Vector3(0.025, 0.031, 0.013), 6, 4)
	# Big round nose.
	m.style(S.SKIN)
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return 1.0 - 0.3 * smoothstep(c.y - 0.06, c.y - 0.1, p.y)
	m.ellipsoid(c + Vector3(0.0, -0.045, -0.212), Vector3(0.05, 0.046, 0.052), 7, 5)
	# Smile.
	m.style(S.DARK, 1.0)
	m.cap_rings = 1
	m.tube(_pts([c + Vector3(-0.06, -0.098, -0.163), c + Vector3(0.0, -0.122, -0.181),
			c + Vector3(0.06, -0.098, -0.163)]), _radii([0.011, 0.015, 0.011]), 4, true, true)
	# Rosy cheeks.
	for s: float in [-1.0, 1.0]:
		m.style(S.BLUSH)
		m.ellipsoid(c + Vector3(s * 0.112, -0.055, -0.15), Vector3(0.038, 0.026, 0.02), 5, 3,
				Basis(Vector3.UP, s * 0.55))
	# Ears.
	for s: float in [-1.0, 1.0]:
		m.style(S.SKIN)
		m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
			return 1.0 - 0.3 * smoothstep(0.0, 0.02, -(absf(p.x) - absf(c.x) - 0.19))
		m.ellipsoid(c + Vector3(s * 0.188, 0.0, 0.01), Vector3(0.03, 0.058, 0.045), 6, 4,
				Basis(Vector3.UP, -s * 0.35))
	return m.build()


## Eyelids for blinking: closed shape; the rig scales it from nothing to full.
static func _lids() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	for s: float in [-1.0, 1.0]:
		m.style(S.SKIN, 0.9)
		m.ellipsoid(Vector3(s * 0.074, 0.0, -0.165), Vector3(0.052, 0.06, 0.042), 6, 4)
	return m.build()


static func _beard() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var c: Vector3 = HEAD_C - BEARD_PIVOT
	var r: Vector3 = HEAD_R * Vector3(1.12, 1.0, 1.12)
	m.style(S.HAIR, 1.0)
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(0.82, 1.0, v)
	m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return (1.0 - v) * 0.6
	# A puffy shell round the jaw from ear to ear, below the smile, ending in ragged tufts.
	m.sheet_wrapped(func(u: float, v: float) -> Vector3:
		var phi: float = lerpf(-1.85, 1.85, u)
		var front: float = smoothstep(1.4, 0.2, absf(phi))
		var lat_top: float = lerpf(-0.2, -0.74, front)
		var lat_bot: float = -1.38 - 0.26 * _spikes(u * 7.0 + 0.5) - 0.14 * front
		var lat: float = lerpf(lat_bot, lat_top, v)
		var d: Vector3 = Vector3(sin(phi) * cos(lat), sin(lat), -cos(phi) * cos(lat))
		var jaw: float = smoothstep(0.15, -0.8, d.y)
		d.x *= 1.0 + 0.11 * jaw
		d.z *= 1.0 + 0.14 * jaw
		# Puff out in the middle of the beard, thin at the cheek line.
		var puff: float = 1.0 + 0.1 * sin(v * PI) * (0.5 + 0.5 * front)
		var p: Vector3 = c + d * r * puff
		# The tufts point down and slightly forward.
		p.y -= (1.0 - v) * 0.025
		p.z -= (1.0 - v) * 0.015 * front
		return p, 12, 3, 0.006, 0.6, false)
	return m.build()


static func _hair_cap(style: StringName) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var c: Vector3 = HEAD_C
	var grow: float = 1.13 if style != &"short" else 1.08
	var fringe: float = 0.24 if style != &"flame" else 0.12
	var puff: float = 0.1 if style == &"mop" else 0.05
	var back_drop: float = 0.8
	if style == &"long":
		back_drop = 1.1
	elif style == &"short":
		back_drop = 0.55
	m.style(S.HAIR, 1.0)
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(0.7, 1.0, smoothstep(0.0, 0.45, v))
	m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return (1.0 - v) * 0.35
	m.grid(func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var z: float = sin(th)
		var front: float = smoothstep(0.2, -0.9, z)
		var back: float = smoothstep(-0.2, 0.9, z)
		var lat_edge: float = 0.2 + front * 0.4 - back * back_drop
		lat_edge -= fringe * _spikes(u * 7.0 + 0.5) * (0.6 + 0.4 * front)
		var lat: float = lerpf(lat_edge, PI * 0.5, v)
		# Lumpy, wild volume: big soft clumps, more on top and at the back.
		var clumps: float = sin(th * 5.0 + lat * 3.0) * sin(th * 3.0 - lat * 2.0 + 1.0)
		var lump: float = 1.0 + (0.05 + puff * 0.4) * clumps * (1.0 - v * 0.5)
		var d: Vector3 = Vector3(cos(lat) * cos(th), sin(lat), cos(lat) * sin(th))
		var mult: float = grow * lump + puff * smoothstep(0.1, 0.9, d.y) + 0.05 * back
		return c + d * HEAD_R * mult, 21, 5, false, true, true)
	return m.build()


## Loose locks on a spring pivot behind the head (HAIR_PIVOT). Style decides their shape.
static func _hair_locks(style: StringName) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var locks: Array = []
	match style:
		&"flame":
			# Upswept flame tongues from the crown, curling back.
			for i in range(7):
				var x: float = lerpf(-0.14, 0.14, float(i) / 6.0)
				var h: float = 0.2 + 0.1 * (1.0 - absf(x) / 0.14)
				locks.append([Vector3(x, -0.04, -0.13), Vector3(x * 1.2, h * 0.75, -0.07),
						Vector3(x * 1.35, h, 0.07 + absf(x) * 0.4), 0.065])
		&"long":
			for i in range(8):
				var x: float = lerpf(-0.17, 0.17, float(i) / 7.0)
				locks.append([Vector3(x, -0.02, -0.02), Vector3(x * 1.25, -0.17, 0.07),
						Vector3(x * 1.35, -0.38 + 0.03 * float(i % 2), 0.05), 0.06])
		&"short":
			# A spiky crop: short tufts standing up all over the top.
			for i in range(6):
				var a: float = float(i) / 6.0 * TAU + 0.3
				var base: Vector3 = Vector3(cos(a) * 0.09, 0.07, -0.1 + sin(a) * 0.08)
				locks.append([base, base + Vector3(cos(a) * 0.03, 0.06, sin(a) * 0.03 + 0.02),
						base + Vector3(cos(a) * 0.06, 0.1, sin(a) * 0.05 + 0.05), 0.05])
		_:
			# Wild mop: thick tufts sticking back and out, over the ears and on top.
			for i in range(5):
				var x: float = lerpf(-0.15, 0.15, float(i) / 4.0)
				locks.append([Vector3(x, 0.0, -0.03), Vector3(x * 1.35, -0.08, 0.08),
						Vector3(x * 1.6, -0.19 + 0.03 * float(i % 2), 0.12), 0.07])
			for s: float in [-1.0, 1.0]:
				locks.append([Vector3(s * 0.15, -0.05, -0.1), Vector3(s * 0.22, -0.11, -0.08),
						Vector3(s * 0.25, -0.17, -0.04), 0.055])
				locks.append([Vector3(s * 0.06, 0.08, -0.12), Vector3(s * 0.09, 0.13, -0.04),
						Vector3(s * 0.12, 0.14, 0.07), 0.055])
	for lock: Array in locks:
		var w: float = lock[3]
		m.style(S.HAIR, 1.0)
		m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
			return lerpf(0.75, 1.0, v)
		m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
			return v
		m.flutter_phase = float(locks.find(lock)) * 1.7
		m.cap_rings = 1
		m.tube(_pts([lock[0], lock[1], lock[2]]), _radii([w, w * 0.72, w * 0.25]), 4, false, true,
				Vector2(1.0, 0.75))
	return m.build()


# --- Torso ---------------------------------------------------------------------------------------

## Radius of the torso at height y (spine space) and angle th (x = cos, z = sin, -z is front).
static func _torso_point(th: float, y: float, inflate: float) -> Vector3:
	var prof: PackedVector2Array = PackedVector2Array([Vector2(0.18, -0.07), Vector2(0.21, 0.02),
			Vector2(0.226, 0.13), Vector2(0.24, 0.24), Vector2(0.25, 0.32), Vector2(0.222, 0.41),
			Vector2(0.14, 0.48), Vector2(0.09, 0.53)])
	var r: float = prof[prof.size() - 1].x
	for i in range(prof.size() - 1):
		if y <= prof[i + 1].y:
			var t: float = clampf((y - prof[i].y) / (prof[i + 1].y - prof[i].y), 0.0, 1.0)
			r = lerpf(prof[i].x, prof[i + 1].x, smoothstep(0.0, 1.0, t))
			break
	if y < prof[0].y:
		r = prof[0].x
	var x: float = cos(th)
	var z: float = sin(th)
	var zs: float = 0.74
	# Pot belly in front, barrel chest, flatter back.
	if z < 0.0:
		zs += 0.2 * exp(-pow((y - 0.1) / 0.11, 2.0)) * (-z)
		zs += 0.06 * exp(-pow((y - 0.3) / 0.08, 2.0)) * (-z)
	else:
		zs -= 0.05
	return Vector3(x * (r + inflate), y, z * (r * zs + inflate))


static func _chest() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	# Bare torso (seen on the uncovered right shoulder and arm-pit).
	m.style(S.SKIN)
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return _occ(p, Vector3(0.2, 0.33, 0.0), 0.08, 0.35) * _occ(p, Vector3(-0.2, 0.33, 0.0), 0.08, 0.35)
	m.grid(func(u: float, v: float) -> Vector3:
		return _torso_point(u * TAU, lerpf(-0.07, 0.53, v), 0.0), 12, 7, false, false, true)
	# Neck cap.
	m.style(S.SKIN)
	m.ellipsoid(Vector3(0.0, 0.52, 0.0), Vector3(0.095, 0.05, 0.085), 6, 3)
	# One-shoulder fur tunic: high over the left shoulder, under the right arm, ragged top.
	m.style(S.FUR, 1.0, 1.0)
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(0.8, 1.0, smoothstep(0.0, 0.3, v)) * lerpf(1.0, 0.85, smoothstep(0.85, 1.0, v))
	m.grid(func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var x: float = cos(th)
		var top: float = lerpf(0.42, 0.21, (x + 1.0) * 0.5) - 0.025 * _spikes(u * 11.0)
		var y: float = lerpf(-0.03, top, v)
		return _torso_point(th, y, 0.018 + 0.006 * sin(th * 9.0)), 14, 4, false, false, true)
	# Shoulder strap over the left shoulder.
	m.style(S.FUR, 0.95, 1.0)
	m.tube(_pts([Vector3(-0.07, 0.36, -0.2), Vector3(-0.16, 0.47, -0.08), Vector3(-0.17, 0.49, 0.04),
			Vector3(-0.08, 0.38, 0.18)]), _radii([0.07, 0.075, 0.075, 0.07]), 5, true, true,
			Vector2(1.0, 0.32), Vector3.UP)
	return m.build()


static func _hips() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	# Pelvis / loin cloth that fills the inside of the skirt.
	m.style(S.MARK, 0.55)
	m.ellipsoid(Vector3(0.0, -0.02, 0.0), Vector3(0.2, 0.13, 0.16), 8, 4)
	# Fur belt with a leather knot and hanging tails.
	m.style(S.MARK, 0.9)
	m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
		return Vector3(p.x, p.y, p.z * (0.84 if p.z > 0.0 else 0.94))
	m.lathe(PackedVector2Array([Vector2(0.205, 0.1), Vector2(0.232, 0.112), Vector2(0.238, 0.135),
			Vector2(0.232, 0.157), Vector2(0.205, 0.168)]), 14)
	m.style(S.LEATHER, 1.0)
	m.ellipsoid(Vector3(-0.07, 0.135, -0.225), Vector3(0.04, 0.035, 0.03), 5, 3)
	m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return 1.0 - v
	m.cap_rings = 1
	m.tube(_pts([Vector3(-0.07, 0.12, -0.235), Vector3(-0.085, 0.03, -0.24), Vector3(-0.08, -0.05, -0.235)]),
			_radii([0.014, 0.012, 0.01]), 4, true, true)
	return m.build()


## The tunic's lower half: a flared fur skirt with a ragged hem (hangs from HEM_PIVOT).
static func _skirt() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	m.style(S.FUR, 1.0, 1.0)
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(0.82, 1.0, smoothstep(0.0, 0.4, v))
	m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return (1.0 - v)
	var fn: Callable = func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var hem: float = 1.0 - v
		var r: float = lerpf(0.218, 0.3, hem * hem * 0.6 + hem * 0.4)
		var y: float = lerpf(0.04, -0.29, hem) - 0.06 * _spikes(u * 10.0) * hem
		# Longer at the back, shorter at the sides.
		y -= 0.03 * smoothstep(0.0, 1.0, sin(th)) * hem
		var zs: float = 0.84 if sin(th) > 0.0 else 0.95
		return Vector3(cos(th) * r, y, sin(th) * r * zs)
	m.sheet_wrapped(fn, 18, 3, 0.012, 0.45)
	return m.build()


# --- Legs ----------------------------------------------------------------------------------------

static func _thigh() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	m.style(S.SKIN)
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return lerpf(0.75, 1.0, smoothstep(0.02, -0.12, p.y))
	m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
		if p.z < 0.0:
			p.z *= 1.0 + 0.12 * exp(-pow((p.y + 0.14) / 0.1, 2.0))
		return p
	m.tube(_pts([Vector3(0.0, 0.04, 0.0), Vector3(0.0, -0.15, -0.005), Vector3(0.0, -THIGH + 0.01, 0.0)]),
			_radii([0.102, 0.094, 0.074]), 8)
	return m.build()


static func _shin() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	m.style(S.SKIN)
	m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
		if p.z > 0.0:
			p.z *= 1.0 + 0.2 * exp(-pow((p.y + 0.1) / 0.08, 2.0))
		return p
	m.tube(_pts([Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.1, 0.004), Vector3(0.0, -0.2, 0.0)]),
			_radii([0.07, 0.076, 0.06]), 7, true, false)
	# Fur foot-wrap with a leather cord, ragged top edge.
	m.style(S.FUR, 1.0, 1.0)
	m.slot_fn = func(p: Vector3, _u: float, _v: float) -> int:
		return S.LEATHER if absf(p.y + 0.235) < 0.014 else -1
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(1.0, 0.85, smoothstep(0.7, 1.0, v))
	m.grid(func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var y: float = lerpf(-SHIN + 0.0, -0.17 + 0.025 * _spikes(u * 8.0), v)
		var r: float = 0.071 + 0.006 * sin(th * 7.0)
		return Vector3(cos(th) * r, y, sin(th) * r * 1.05), 9, 3, false, false, true)
	return m.build()


## Fur-wrapped foot with bare toes peeking out (ankle pivot at the origin).
static func _foot(_side: float) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	m.style(S.FUR, 1.0, 1.0)
	m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
		p.y = maxf(p.y, -ANKLE_Y)
		return p
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return lerpf(0.7, 1.0, smoothstep(-ANKLE_Y, -ANKLE_Y + 0.03, p.y))
	m.ellipsoid(Vector3(0.0, -0.035, -0.05), Vector3(0.08, 0.066, 0.135), 8, 5)
	# Leather cord over the instep.
	m.style(S.LEATHER, 0.9)
	m.cap_rings = 1
	m.tube(_pts([Vector3(-0.078, -0.045, -0.085), Vector3(0.0, 0.022, -0.095), Vector3(0.078, -0.045, -0.085)]),
			_radii([0.011, 0.012, 0.011]), 3)
	# Bare toes poking out of the wrap.
	m.style(S.SKIN, 1.0)
	m.ellipsoid(Vector3(0.0, -0.058, -0.172), Vector3(0.064, 0.036, 0.047), 7, 4)
	return m.build()


# --- Arms ----------------------------------------------------------------------------------------

static func _upper_arm(side: float) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	m.style(S.SKIN)
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return lerpf(0.8, 1.0, smoothstep(-0.03, 0.03, p.x * -side))
	m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
		if p.z < 0.0:
			p.z *= 1.0 + 0.18 * exp(-pow((p.y + 0.16) / 0.07, 2.0))
		return p
	m.tube(_pts([Vector3(0.0, 0.03, 0.0), Vector3(side * 0.01, -0.08, 0.0), Vector3(0.0, -0.19, 0.0),
			Vector3(0.0, -UPPER_ARM + 0.01, 0.0)]), _radii([0.097, 0.09, 0.079, 0.062]), 8)
	return m.build()


static func _forearm(side: float) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	m.style(S.SKIN)
	m.slot_fn = func(p: Vector3, _u: float, _v: float) -> int:
		return S.LEATHER if p.y < -0.205 and p.y > -0.24 else -1
	m.tube(_pts([Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.09, -0.005), Vector3(0.0, -0.2, 0.0),
			Vector3(0.0, -0.235, 0.0)]), _radii([0.062, 0.077, 0.06, 0.055]), 7)
	# Mitten hand (a loose fist) and a thumb on the inner side.
	m.style(S.SKIN)
	m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
		return lerpf(0.8, 1.0, smoothstep(-0.27, -0.3, p.y))
	m.ellipsoid(Vector3(0.0, -0.305, -0.008), Vector3(0.062, 0.08, 0.052), 7, 5)
	m.style(S.SKIN, 0.95)
	m.cap_rings = 1
	m.tube(_pts([Vector3(-side * 0.045, -0.27, -0.035), Vector3(-side * 0.057, -0.305, -0.058)]),
			_radii([0.025, 0.021]), 4)
	return m.build()


# --- Accessories ---------------------------------------------------------------------------------

## Accessory meshes, named <kind>_<part>. See accessory_parts().
static func _accessory_part(key: StringName) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var c: Vector3 = HEAD_C
	match key:
		&"cap_head":
			# Top-knot tied with a cord, a bone pushed through it.
			m.style(S.HAIR)
			m.ellipsoid(c + Vector3(0.0, 0.265, 0.03), Vector3(0.075, 0.07, 0.072), 8, 6)
			m.xf = Transform3D(Basis.IDENTITY, Vector3(c.x, c.y, 0.03))
			m.style(S.LEATHER)
			m.lathe(PackedVector2Array([Vector2(0.056, 0.215), Vector2(0.066, 0.23), Vector2(0.056, 0.245)]), 8)
			m.style(S.BONE, 1.0, 0.0, 0.35)
			m.tube(_pts([Vector3(-0.15, 0.27, 0.0), Vector3(0.15, 0.27, 0.0)]), _radii([0.019, 0.019]), 6,
					false, false)
			for s: float in [-1.0, 1.0]:
				for k: float in [-1.0, 1.0]:
					m.style(S.BONE, 1.0, 0.0, 0.35)
					m.ellipsoid(Vector3(s * 0.16, 0.27 + k * 0.018, 0.0), Vector3(0.026, 0.026, 0.026), 6, 4)
		&"visor_head":
			# Raptor skull worn as a helmet: dome, long toothy snout, dark eye sockets.
			m.style(S.BONE, 1.0, 0.0, 0.25)
			m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
				p.y = maxf(p.y, c.y + 0.07 - 0.03 * smoothstep(0.0, 0.2, p.z - c.z))
				return p
			m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
				return lerpf(0.7, 1.0, smoothstep(c.y + 0.07, c.y + 0.12, p.y))
			m.ellipsoid(c + Vector3(0.0, 0.08, 0.01), Vector3(0.228, 0.205, 0.232), 12, 6)
			# Snout jutting forward and up over the brow, a horn bump on the nose.
			m.style(S.BONE, 1.0, 0.0, 0.25)
			m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
				return lerpf(0.75, 1.0, smoothstep(c.y + 0.13, c.y + 0.2, p.y))
			m.tube(_pts([c + Vector3(0.0, 0.2, -0.12), c + Vector3(0.0, 0.2, -0.27), c + Vector3(0.0, 0.17, -0.38)]),
					_radii([0.09, 0.062, 0.035]), 7, false, true, Vector2(1.0, 0.72), Vector3.UP)
			m.style(S.BONE, 1.0, 0.0, 0.3)
			m.cap_rings = 1
			m.tube(_pts([c + Vector3(0.0, 0.24, -0.28), c + Vector3(0.0, 0.3, -0.27)]), _radii([0.022, 0.006]), 4,
					true, true)
			for s: float in [-1.0, 1.0]:
				# Dark eye holes, nostril.
				m.style(S.PUPIL, 0.5)
				m.ellipsoid(c + Vector3(s * 0.12, 0.165, -0.17), Vector3(0.048, 0.04, 0.03), 5, 3,
						Basis(Vector3.UP, s * 0.55))
				# Upper teeth hanging over the forehead like a visor.
				for i in range(3):
					var a: float = (float(i) + 0.5) * 0.28
					var base: Vector3 = c + Vector3(s * sin(a) * 0.2, 0.1, -cos(a) * 0.205)
					m.style(S.BONE, 1.0, 0.0, 0.4)
					m.cap_rings = 1
					m.tube(_pts([base, base + Vector3(0.0, -0.05, -0.012)]), _radii([0.016, 0.004]), 4, false, true)
		&"antenna_head":
			# Leather headband.
			m.style(S.LEATHER, 0.95)
			m.xf = Transform3D(Basis(Vector3.RIGHT, -0.12), c + Vector3(0.0, 0.1, 0.0))
			m.lathe(PackedVector2Array([Vector2(0.212, -0.022), Vector2(0.226, 0.0), Vector2(0.212, 0.024)]), 16)
		&"antenna_feathers":
			# Two feathers on a spring (FEATHER_PIVOT) plus a short one.
			var specs: Array = [[Vector3(0.0, 0.0, 0.0), 0.32, -0.25, 0.0], [Vector3(0.025, -0.01, 0.02), 0.25, -0.05, 0.35],
					[Vector3(-0.02, 0.0, 0.03), 0.18, -0.45, -0.3]]
			for spec: Array in specs:
				var base: Vector3 = spec[0]
				var length: float = spec[1]
				var tilt: float = spec[2]
				var yaw: float = spec[3]
				var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt) * Basis(Vector3.BACK, -0.35)
				m.style(S.ACCENT, 1.0)
				m.slot_fn = func(_p: Vector3, _u: float, v: float) -> int:
					return S.DARK if v > 0.82 else (S.BONE if v < 0.12 else -1)
				m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
					return v * 0.8
				m.xf = Transform3D(basis, base)
				m.sheet(func(u: float, v: float) -> Vector3:
					var w: float = sin(clampf(v, 0.0, 1.0) * PI) * 0.045 * (0.6 + 0.4 * v)
					var bend: float = v * v * 0.06
					return Vector3((u - 0.5) * 2.0 * w, v * length, bend + absf(u - 0.5) * 0.01), 2, 6, 0.004)
		&"backpack_back":
			# Stone club strapped diagonally across the back.
			m.style(S.LEATHER, 0.9)
			m.tube(_pts([Vector3(0.2, -0.02, 0.23), Vector3(0.0, 0.25, 0.27), Vector3(-0.17, 0.5, 0.27)]),
					_radii([0.028, 0.03, 0.034]), 6)
			m.style(S.STONE, 1.0, 0.0, 0.1)
			m.deform = func(p: Vector3, _u: float, _v: float) -> Vector3:
				var cc: Vector3 = Vector3(-0.21, 0.58, 0.28)
				var d: Vector3 = p - cc
				var lump: float = 1.0 + 0.12 * sin(d.x * 60.0) * sin(d.y * 50.0 + 1.0) * cos(d.z * 55.0)
				return cc + d * lump
			m.ao_fn = func(p: Vector3, _u: float, _v: float) -> float:
				return lerpf(0.75, 1.0, smoothstep(0.5, 0.6, p.y))
			m.ellipsoid(Vector3(-0.21, 0.58, 0.28), Vector3(0.105, 0.12, 0.095), 9, 6,
					Basis(Vector3.BACK, 0.6))
			m.style(S.LEATHER, 0.85)
			m.xf = Transform3D(Basis(Vector3.BACK, 0.6), Vector3(-0.16, 0.49, 0.27))
			m.lathe(PackedVector2Array([Vector2(0.04, -0.015), Vector2(0.046, 0.0), Vector2(0.04, 0.015)]), 8)
		&"backpack_strap":
			m.style(S.LEATHER, 0.9)
			m.tube(_pts([Vector3(0.21, 0.42, 0.08), Vector3(0.15, 0.38, -0.17), Vector3(0.0, 0.24, -0.22),
					Vector3(-0.16, 0.08, -0.19), Vector3(-0.22, 0.0, 0.02)]), _radii([0.035, 0.035, 0.035, 0.035, 0.035]),
					5, true, true, Vector2(1.0, 0.3), Vector3(0, 0, -1))
		&"scarf_back":
			# Fur shawl round the shoulders, ragged edge.
			m.style(S.FUR, 1.0, 1.0)
			m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
				return lerpf(1.0, 0.8, v)
			m.flutter_fn = func(_p: Vector3, _u: float, v: float) -> float:
				return (1.0 - v) * 0.6
			m.sheet_wrapped(func(u: float, v: float) -> Vector3:
				var th: float = u * TAU
				var t: float = 1.0 - v
				var r: float = lerpf(0.13, 0.34, t)
				var y: float = lerpf(0.56, 0.36, t * t * 0.4 + t * 0.6) - 0.05 * _spikes(u * 12.0) * t
				var zs: float = 0.85 if sin(th) > 0.0 else 0.95
				return Vector3(cos(th) * r * 1.02, y, sin(th) * r * zs), 16, 3, 0.012, 0.5)
		&"scarf_neck":
			# Tooth necklace on a leather cord.
			m.style(S.LEATHER, 0.9)
			m.tube(_pts([Vector3(-0.14, 0.47, -0.06), Vector3(-0.09, 0.4, -0.19), Vector3(0.0, 0.375, -0.225),
					Vector3(0.09, 0.4, -0.19), Vector3(0.14, 0.47, -0.06)]), _radii([0.009, 0.009, 0.009, 0.009, 0.009]),
					4, false, false)
			for i in range(5):
				var t: float = float(i - 2) / 2.0
				var p: Vector3 = Vector3(t * 0.085, 0.383 + absf(t) * 0.018, -0.225 + absf(t) * 0.02)
				m.style(S.BONE, 1.0, 0.0, 0.4)
				m.cap_rings = 1
				m.tube(_pts([p, p + Vector3(t * 0.006, -0.06 + absf(t) * 0.01, -0.012)]),
						_radii([0.017, 0.006]), 4, false, true)
	return m.build()


## Accessory pieces for a CharacterDef.accessory value: [part mesh name, bone name, spring?].
## Bones: head, spine, feather (spring pivot on the head).
static func accessory_parts(kind: StringName) -> Array:
	match kind:
		&"cap":
			return [[&"acc_cap_head", &"head"]]
		&"visor":
			return [[&"acc_visor_head", &"head"]]
		&"antenna":
			return [[&"acc_antenna_head", &"head"], [&"acc_antenna_feathers", &"feather"]]
		&"backpack":
			return [[&"acc_backpack_back", &"spine"], [&"acc_backpack_strap", &"spine"]]
		&"scarf":
			return [[&"acc_scarf_back", &"spine"], [&"acc_scarf_neck", &"spine"]]
	return []
