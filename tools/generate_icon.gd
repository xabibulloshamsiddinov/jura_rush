## Generates the app icon and splash image procedurally (no art files needed).
##   godot --headless --path . --script res://tools/generate_icon.gd
## Writes assets/textures/icon.png (512), icon_foreground.png (432, adaptive icon layer) and
## splash.png (1080 x 1920).
extends SceneTree

const BACKGROUND: Color = Color(0.03, 0.035, 0.09)
const CYAN: Color = Color(0.0, 0.9, 1.0)
const MAGENTA: Color = Color(1.0, 0.2, 0.8)
const YELLOW: Color = Color(1.0, 0.86, 0.1)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/textures")
	_icon(512, true).save_png("res://assets/textures/icon.png")
	_icon(432, false).save_png("res://assets/textures/icon_foreground.png")
	_splash().save_png("res://assets/textures/splash.png")
	print("icon.png, icon_foreground.png and splash.png written to assets/textures/")
	quit()


## Three neon rails converging on a horizon, with a glowing runner dot.
func _icon(size: int, with_background: bool) -> Image:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s: float = float(size)
	var horizon: Vector2 = Vector2(s * 0.5, s * 0.3)
	for y in range(size):
		for x in range(size):
			var p: Vector2 = Vector2(float(x), float(y))
			var color: Color = Color(0.0, 0.0, 0.0, 0.0)
			if with_background:
				var corner: float = _rounded_box(p - Vector2(s, s) * 0.5, Vector2(s, s) * 0.5, s * 0.2)
				if corner <= 0.0:
					color = BACKGROUND.lerp(Color(0.16, 0.05, 0.3), float(y) / s)
			var glow: Color = Color(0.0, 0.0, 0.0, 0.0)
			if p.y > horizon.y:
				for i in range(4):
					var bottom: Vector2 = Vector2(s * (0.05 + 0.3 * float(i)), s * 1.02)
					var d: float = _segment_distance(p, horizon, bottom)
					var width: float = s * 0.012 * (0.4 + 1.6 * (p.y - horizon.y) / s)
					var a: float = clampf(1.0 - d / width, 0.0, 1.0) + 0.35 * clampf(1.0 - d / (width * 4.0), 0.0, 1.0)
					var rail: Color = CYAN if i % 3 == 0 else MAGENTA
					glow = glow.lerp(rail, clampf(a, 0.0, 1.0))
					glow.a = maxf(glow.a, clampf(a, 0.0, 1.0))
			var runner: float = p.distance_to(Vector2(s * 0.5, s * 0.62))
			var dot: float = clampf(1.0 - runner / (s * 0.09), 0.0, 1.0)
			var halo: float = clampf(1.0 - runner / (s * 0.2), 0.0, 1.0) * 0.5
			if dot + halo > 0.0:
				glow = glow.lerp(YELLOW, clampf(dot * 2.0 + halo, 0.0, 1.0))
				glow.a = maxf(glow.a, clampf(dot * 2.0 + halo, 0.0, 1.0))
			if with_background and color.a > 0.0:
				color = color.lerp(Color(glow.r, glow.g, glow.b, 1.0), glow.a)
				color.a = 1.0
			elif not with_background:
				color = glow
			image.set_pixel(x, y, color)
	return image


func _splash() -> Image:
	var image: Image = Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
	image.fill(BACKGROUND)
	var icon: Image = _icon(432, false)
	image.blend_rect(icon, Rect2i(0, 0, 432, 432), Vector2i(324, 744))
	return image


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _rounded_box(p: Vector2, half: Vector2, radius: float) -> float:
	var q: Vector2 = p.abs() - half + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
