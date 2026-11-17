## Look data of the four Jura Rush biome styles that BiomeDef does not carry as plain colours.
## A style index is BiomeDef.decor_set (0 Fern Valley, 1 Red Canyon, 2 Misty Swamp,
## 3 Volcano Ridge). BiomeDef supplies the sky / fog / sun colours, the foliage tint (accent,
## alpha = lushness) and the rock / path-stone tint (accent2, alpha = heat).
class_name BiomeStyle
extends RefCounted

const FERN_VALLEY: int = 0
const RED_CANYON: int = 1
const MISTY_SWAMP: int = 2
const VOLCANO_RIDGE: int = 3
const COUNT: int = 4

## Bare earth beside the paths.
const EARTH: Array[Color] = [
	Color(0.52, 0.37, 0.24), Color(0.72, 0.43, 0.28), Color(0.3, 0.26, 0.18), Color(0.33, 0.29, 0.27)]
## Dark grass patches (the light grass is BiomeDef.accent).
const GRASS_DARK: Array[Color] = [
	Color(0.22, 0.45, 0.16), Color(0.52, 0.48, 0.24), Color(0.13, 0.3, 0.14), Color(0.3, 0.28, 0.2)]
## Cliffs, boulders, hoodoos and mesas of the side decor (the path stone is BiomeDef.accent2).
const CLIFF: Array[Color] = [
	Color(0.56, 0.52, 0.47), Color(0.8, 0.5, 0.33), Color(0.46, 0.47, 0.41), Color(0.34, 0.3, 0.28)]
## Crevices between flagstones.
const CREVICE: Array[Color] = [
	Color(0.28, 0.24, 0.2), Color(0.5, 0.28, 0.17), Color(0.17, 0.19, 0.14), Color(0.1, 0.085, 0.08)]
## Ground extras: y = swamp water strips beside the path, w = dry-mud cracks. (x and z are filled
## from the BiomeDef: lushness and heat.)
const GROUND_EXTRA: Array[Vector4] = [
	Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0),
	Vector4(0.0, 1.0, 0.0, 0.0), Vector4(0.0, 0.0, 0.0, 0.35)]
## Sky dome: far and near silhouette tints, cloud amount.
const SKY_FAR: Array[Color] = [
	Color(0.42, 0.56, 0.62), Color(0.86, 0.56, 0.42), Color(0.5, 0.62, 0.58), Color(0.42, 0.34, 0.34)]
const SKY_NEAR: Array[Color] = [
	Color(0.2, 0.38, 0.27), Color(0.7, 0.36, 0.22), Color(0.22, 0.34, 0.29), Color(0.17, 0.14, 0.14)]
const CLOUDS: Array[float] = [0.55, 0.3, 0.8, 0.45]


## Style index of a BiomeDef, clamped to the known styles.
static func of(def: BiomeDef) -> int:
	return clampi(def.decor_set, 0, COUNT - 1)


## The BiomeDef using a style (first match), or null.
static func def_for(style: int) -> BiomeDef:
	for def: BiomeDef in ContentDB.BIOMES:
		if of(def) == style:
			return def
	return null


## Foliage colour of a style (BiomeDef.accent rgb), with a fallback.
static func foliage(style: int) -> Color:
	var def: BiomeDef = def_for(style)
	var c: Color = def.accent if def != null else Color(0.34, 0.6, 0.22)
	return Color(c.r, c.g, c.b)


## Rock / path-stone colour of a style (BiomeDef.accent2 rgb), with a fallback.
static func rock(style: int) -> Color:
	var def: BiomeDef = def_for(style)
	var c: Color = def.accent2 if def != null else Color(0.63, 0.59, 0.53)
	return Color(c.r, c.g, c.b)


## Ground parameters (x lushness, y water, z heat, w dry cracks) of a style.
static func ground_params(style: int) -> Vector4:
	var def: BiomeDef = def_for(style)
	var extra: Vector4 = GROUND_EXTRA[clampi(style, 0, COUNT - 1)]
	var lush: float = def.accent.a if def != null else 1.0
	var heat: float = def.accent2.a if def != null else 0.0
	return Vector4(lush, extra.y, heat, extra.w)
