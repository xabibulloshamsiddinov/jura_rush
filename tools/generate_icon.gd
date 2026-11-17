## Generates the app icon and the splash image procedurally (no art files needed).
##   godot --path . --script res://tools/generate_icon.gd
## Needs a real renderer, so do NOT pass --headless (a window opens for a second or two).
## Writes assets/textures/icon.png (512), icon_foreground.png (432, adaptive icon layer, art inside
## the 66 % safe zone) and splash.png (1080 x 1920: the loading-screen sunset plus the logo and the
## icon art).
##
## Icon: a stylised T-Rex head in profile (dark silhouette with a cream sticker outline, open jaws,
## amber eye) about to bite a speckled egg, on a warm sunrise gradient.
##
## This is a main-loop script, so project classes that depend on autoloads (the logo) are loaded
## at run time instead of being named at compile time.
extends SceneTree

const LOGO_PATH: String = "res://scripts/ui/game_logo.gd"
const BACKDROP_PATH: String = "res://scripts/ui/jura_backdrop.gd"


## The icon plate: a warm sunrise gradient with a soft sun glow. Its alpha clips the figure drawn
## on top (clip_children), so nothing can poke out of the rounded corners.
class IconPlate extends Control:
	const TOP: Color = Color(1.0, 0.83, 0.33)
	const BOTTOM: Color = Color(0.92, 0.36, 0.10)

	## 1 = rounded square (launcher icon), 2 = full bleed (adaptive foreground).
	var plate: int = 1

	func _draw() -> void:
		_plate(size.x)

	func _plate(s: float) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		var cols: PackedColorArray = PackedColorArray()
		if plate == 2:
			pts = PackedVector2Array([Vector2(0.0, 0.0), Vector2(s, 0.0), Vector2(s, s), Vector2(0.0, s)])
		else:
			var r: float = s * 0.2
			var corners: Array[Vector2] = [Vector2(s - r, r), Vector2(s - r, s - r), Vector2(r, s - r), Vector2(r, r)]
			for k in range(4):
				for i in range(13):
					var a: float = deg_to_rad(-90.0 + 90.0 * float(k) + 7.5 * float(i))
					pts.append(corners[k] + Vector2(cos(a), sin(a)) * r)
		for p: Vector2 in pts:
			cols.append(TOP.lerp(BOTTOM, clampf(p.y / s, 0.0, 1.0)))
		draw_polygon(pts, cols)
		# Sun glow behind the head: a fan with a bright centre and a transparent rim, so it has no
		# visible rings (kept well inside the rounded corners).
		var sun: Vector2 = Vector2(s * 0.58, s * 0.46)
		var fan: PackedVector2Array = PackedVector2Array([sun])
		var fan_colors: PackedColorArray = PackedColorArray([Color(1.0, 0.96, 0.66, 0.6)])
		for i in range(49):
			var a: float = TAU * float(i) / 48.0
			fan.append(sun + Vector2(cos(a), sin(a)) * s * 0.46)
			fan_colors.append(Color(1.0, 0.9, 0.5, 0.0))
		draw_polygon(fan, fan_colors)


## The artwork itself: a T-Rex head with a cream sticker outline and a speckled egg.
class IconFigure extends Control:
	const DARK: Color = Color(0.20, 0.10, 0.06)
	const CREAM: Color = Color(1.0, 0.95, 0.78)

	## 1.0 = the art fills the canvas; 0.62 keeps it inside the adaptive-icon safe zone.
	var art_scale: float = 1.0

	func _draw() -> void:
		_trex(size.x)

	## Normalised art coordinates (0..1) to canvas pixels, scaled about the centre.
	func _p(x: float, y: float) -> Vector2:
		var s: float = size.x
		return Vector2(s * 0.5, s * 0.5) + (Vector2(x, y) - Vector2(0.5, 0.5)) * s * art_scale

	func _pts(points: Array[Vector2]) -> PackedVector2Array:
		var out: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in points:
			out.append(_p(p.x, p.y))
		return out

	func _trex(s: float) -> void:
		# The neck always runs off the bottom edge of the canvas, whatever the art scale.
		var bottom: float = 0.5 + 0.55 / art_scale
		var neck: PackedVector2Array = _pts([Vector2(0.04, bottom), Vector2(0.08, 0.78), Vector2(0.13, 0.60), Vector2(0.17, 0.50),
				Vector2(0.30, 0.50), Vector2(0.38, 0.62), Vector2(0.42, 0.80), Vector2(0.40, bottom)])
		var head: PackedVector2Array = _pts([Vector2(0.15, 0.52), Vector2(0.15, 0.40), Vector2(0.22, 0.31),
				Vector2(0.33, 0.26), Vector2(0.45, 0.245), Vector2(0.55, 0.265), Vector2(0.63, 0.30),
				Vector2(0.76, 0.32), Vector2(0.86, 0.335), Vector2(0.915, 0.375), Vector2(0.925, 0.44),
				Vector2(0.895, 0.50), Vector2(0.80, 0.535), Vector2(0.66, 0.545), Vector2(0.52, 0.56),
				Vector2(0.40, 0.60), Vector2(0.29, 0.62), Vector2(0.19, 0.60)])
		# Lower jaw, swung open around the hinge.
		var hinge: Vector2 = Vector2(0.34, 0.60)
		var jaw_open: float = deg_to_rad(16.0)
		var jaw_raw: Array[Vector2] = [Vector2(0.34, 0.60), Vector2(0.48, 0.625), Vector2(0.62, 0.615),
				Vector2(0.76, 0.595), Vector2(0.855, 0.575), Vector2(0.84, 0.64), Vector2(0.72, 0.70),
				Vector2(0.55, 0.74), Vector2(0.40, 0.75), Vector2(0.28, 0.71)]
		var jaw_pts: Array[Vector2] = []
		for p: Vector2 in jaw_raw:
			jaw_pts.append(hinge + (p - hinge).rotated(jaw_open))
		var jaw: PackedVector2Array = _pts(jaw_pts)
		# Egg in front of the jaws, bottom left.
		var egg_c: Vector2 = _p(0.27, 0.86)
		var egg: PackedVector2Array = PackedVector2Array()
		for i in range(41):
			var a: float = TAU * float(i) / 40.0
			egg.append(egg_c + Vector2(sin(a) * 0.35 * (1.0 - 0.16 * cos(a)), -cos(a) * 0.45 + 0.02) * s * 0.34 * art_scale)
		# Cream sticker outline behind everything.
		var sticker: float = s * 0.016 * art_scale
		for poly: PackedVector2Array in [neck, head, jaw, egg]:
			for ring: PackedVector2Array in Geometry2D.offset_polygon(poly, sticker, Geometry2D.JOIN_ROUND):
				draw_colored_polygon(ring, CREAM)
		# Dark mouth interior, then the silhouette.
		var mouth: PackedVector2Array = _pts([Vector2(0.34, 0.60), Vector2(0.50, 0.57), Vector2(0.68, 0.55),
				Vector2(0.84, 0.545), Vector2(0.86, 0.60), Vector2(0.70, 0.66), Vector2(0.52, 0.665)])
		draw_colored_polygon(neck, DARK)
		draw_colored_polygon(head, DARK)
		draw_colored_polygon(jaw, DARK)
		draw_colored_polygon(mouth, Color(0.62, 0.14, 0.10))
		# Warm rim light along the top of the skull and a lighter belly line on the jaw.
		draw_polyline(_pts([Vector2(0.18, 0.37), Vector2(0.25, 0.31), Vector2(0.36, 0.27), Vector2(0.47, 0.262),
				Vector2(0.56, 0.285)]), Color(0.78, 0.42, 0.18, 0.9), s * 0.014 * art_scale, true)
		# Teeth: cream triangles hanging from the upper lip and rising from the lower jaw.
		for i in range(7):
			var x: float = 0.52 + 0.05 * float(i)
			var lip_y: float = lerpf(0.560, 0.538, float(i) / 6.0)
			draw_colored_polygon(_pts([Vector2(x, lip_y - 0.004), Vector2(x + 0.036, lip_y - 0.004),
					Vector2(x + 0.018, lip_y + 0.062 - 0.004 * float(i % 2))]), CREAM)
		for i in range(5):
			var along: float = 0.50 + 0.07 * float(i)
			var base: Vector2 = hinge + (Vector2(along, lerpf(0.628, 0.585, float(i) / 4.0)) - hinge).rotated(jaw_open)
			var up: Vector2 = Vector2(0.0, -0.05).rotated(jaw_open)
			draw_colored_polygon(PackedVector2Array([_p(base.x, base.y), _p(base.x + 0.034, base.y + 0.008),
					_p(base.x + 0.014 + up.x, base.y + up.y)]), CREAM)
		# Eye with a heavy brow, nostril.
		draw_colored_polygon(_pts([Vector2(0.40, 0.335), Vector2(0.60, 0.325), Vector2(0.58, 0.355), Vector2(0.42, 0.375)]), DARK)
		draw_circle(_p(0.505, 0.385), s * 0.043 * art_scale, Color(1.0, 0.78, 0.12), true, -1.0, true)
		draw_circle(_p(0.515, 0.388), s * 0.022 * art_scale, DARK, true, -1.0, true)
		draw_circle(_p(0.495, 0.372), s * 0.009 * art_scale, Color.WHITE, true, -1.0, true)
		draw_circle(_p(0.86, 0.405), s * 0.014 * art_scale, Color(0.55, 0.28, 0.14), true, -1.0, true)
		# Speckled egg.
		draw_colored_polygon(egg, Color(0.95, 0.80, 0.52))
		var lit: PackedVector2Array = PackedVector2Array()
		for q: Vector2 in egg:
			lit.append(egg_c + (q - egg_c) * 0.9 + Vector2(-0.012, -0.015) * s * art_scale)
		draw_colored_polygon(lit, CREAM)
		for dot: Vector3 in [Vector3(0.10, 0.12, 0.05), Vector3(-0.12, 0.2, 0.04), Vector3(0.16, -0.06, 0.035),
				Vector3(-0.04, -0.1, 0.03), Vector3(0.02, 0.3, 0.035), Vector3(-0.16, 0.0, 0.028)]:
			draw_circle(egg_c + Vector2(dot.x, dot.y) * s * 0.34 * art_scale, dot.z * s * 0.34 * art_scale,
					Color(0.52, 0.36, 0.2, 0.85), true, -1.0, true)
		draw_polyline(egg + PackedVector2Array([egg[0]]), DARK, s * 0.014 * art_scale, true)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/textures")
	_render()


func _render() -> void:
	await process_frame
	var icon: Image = await _capture_icon(512, 1, 1.0)
	icon.save_png("res://assets/textures/icon.png")
	var foreground: Image = await _capture_icon(432, 2, 0.62)
	foreground.save_png("res://assets/textures/icon_foreground.png")
	var splash: Image = await _capture_splash()
	splash.save_png("res://assets/textures/splash.png")
	print("icon.png, icon_foreground.png and splash.png written to assets/textures/")
	quit()


func _viewport(size: Vector2i, transparent: bool) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _grab(viewport: SubViewport) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## Plate (rounded square or full bleed) with the figure on it, `pixels` wide.
func _make_icon(pixels: float, plate_kind: int, art_scale: float) -> Control:
	var holder: IconPlate = IconPlate.new()
	holder.plate = plate_kind
	holder.size = Vector2(pixels, pixels)
	if plate_kind == 1:
		holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var figure: IconFigure = IconFigure.new()
	figure.size = holder.size
	figure.art_scale = art_scale
	holder.add_child(figure)
	return holder


func _capture_icon(pixels: int, plate_kind: int, art_scale: float) -> Image:
	var viewport: SubViewport = _viewport(Vector2i(pixels, pixels), plate_kind == 1)
	viewport.add_child(_make_icon(float(pixels), plate_kind, art_scale))
	return await _grab(viewport)


## The loading-screen sunset, the logo and a big icon medallion.
func _capture_splash() -> Image:
	var viewport: SubViewport = _viewport(Vector2i(1080, 1920), false)
	var backdrop: Control = (load(BACKDROP_PATH) as GDScript).new() as Control
	backdrop.size = Vector2(1080.0, 1920.0)
	viewport.add_child(backdrop)
	var logo: Control = (load(LOGO_PATH) as GDScript).new("JURA RUSH", 230) as Control
	logo.size = logo.custom_minimum_size
	logo.position = Vector2((1080.0 - logo.size.x) * 0.5, 250.0)
	viewport.add_child(logo)
	var medallion: Control = _make_icon(360.0, 1, 1.0)
	medallion.position = Vector2(360.0, 1440.0)
	viewport.add_child(medallion)
	return await _grab(viewport)
