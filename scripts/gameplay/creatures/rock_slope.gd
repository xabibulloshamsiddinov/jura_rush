## Mossy rock slope: the visual of a ramp that does NOT lead into a sauropod. Its top surface is
## the ramp's walkable incline (0 at the near end, `height` at the far end); bumpy, mottled sides
## and a rounded boulder at the high end. Built once per size and shared.
class_name RockSlope
extends RefCounted

const ROCK: Color = Color(0.58, 0.54, 0.48)
const ROCK_DARK: Color = Color(0.4, 0.37, 0.33)
const MOSS: Color = Color(0.4, 0.52, 0.25)


## Mesh in obstacle space (centred on the ramp, near end at +length / 2).
static func mesh(length: float, height: float) -> ArrayMesh:
	return OrganicMesh.cached("rock_slope_%.2f_%.2f" % [length, height],
			RockSlope._build.bind(length, height)) as ArrayMesh


static func _paint(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
	var c: Color = ROCK.lerp(ROCK_DARK, smoothstep(0.1, 0.5, OrganicMesh.noise3(p, 2.2, 3.0)))
	var moss: float = smoothstep(0.55, 0.8, n.y + 0.3 * OrganicMesh.noise3(p, 1.6, 8.0)) * 0.9
	return c.lerp(MOSS.darkened(0.15 * OrganicMesh.noise3(p, 4.0)), moss)


static func _build(length: float, height: float) -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new()
	om.paint = RockSlope._paint
	# Bumps only on the sides and underneath: the top stays exactly on the incline.
	om.displace = func(p: Vector3, out: Vector3) -> Vector3:
		return out * (0.07 + 0.07 * OrganicMesh.noise3(p, 1.3, 2.0)) * (1.0 - smoothstep(0.35, 0.8, out.y))
	var up: Vector3 = Vector3(0.0, length, height).normalized()
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedVector2Array = PackedVector2Array()
	var ups: PackedVector3Array = PackedVector3Array()
	var steps: int = 6
	for k in range(steps + 1):
		var t: float = float(k) / float(steps)
		var top: Vector3 = Vector3(0.0, height * t, length * 0.5 - length * t)
		var ry: float = 0.22 + height * t * 0.5
		pts.append(top - up * ry)
		radii.append(Vector2(0.86 + 0.06 * sin(t * PI), ry))
		ups.append(up)
	var exps: PackedFloat32Array = PackedFloat32Array()
	for i in range(pts.size()):
		exps.append(3.2)
	om.loft(pts, radii, 16, 2, {"ups": ups, "exps": exps, "cap0": OrganicMesh.CAP_ROUND,
			"cap1": OrganicMesh.CAP_FLAT, "cap_len0": 0.6})
	# Boulder at the high end (top flush with the walkable height).
	om.displace = func(p: Vector3, out: Vector3) -> Vector3:
		return out * 0.08 * OrganicMesh.noise3(p, 1.5, 4.0) * (1.0 - smoothstep(0.6, 0.9, out.y))
	om.ellipsoid(Vector3(0.0, height * 0.45, -length * 0.5 + 0.35), Vector3(0.95, height * 0.55, 0.85), 8, 14)
	# A couple of loose stones at the foot.
	om.displace = Callable()
	om.ellipsoid(Vector3(0.75, 0.12, length * 0.5 - 0.6), Vector3(0.28, 0.18, 0.24), 4, 7)
	om.ellipsoid(Vector3(-0.8, 0.15, length * 0.1), Vector3(0.24, 0.2, 0.3), 4, 7)
	return om.commit()
