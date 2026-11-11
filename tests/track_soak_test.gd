## Treadmill soak test: 10 simulated minutes of the endless track, stepped as fast as the CPU
## allows. Asserts no gaps > 0.01 m between chunks, a constant active chunk count and no node
## leaks (pools stop growing after warm-up).   godot --headless --path . res://tests/track_soak_test.tscn
extends Node

const SIM_SECONDS: float = 600.0
const STEP: float = 1.0 / 60.0


func _ready() -> void:
	var cfg: GameConfig = GameConfig.current()
	Factories.register_pools(cfg.active_chunks)
	var director: DifficultyDirector = DifficultyDirector.new()
	add_child(director)
	var track: TrackManager = TrackManager.new()
	track.director = director
	add_child(track)
	track.reset(12345, false)
	var chunk_count: int = track.chunks.size()
	var steps: int = int(SIM_SECONDS / STEP)
	var count_ok: bool = true
	var created_mark: int = 0
	var in_use_peak: int = 0
	for i in range(steps):
		director.tick(STEP)
		track.target_speed = director.target_speed()
		track.advance(STEP)
		if track.chunks.size() != chunk_count:
			count_ok = false
		if i == steps / 3:
			created_mark = PoolManager.total_created()
		in_use_peak = maxi(in_use_peak, PoolManager.total_in_use())
		if i % 6000 == 0:
			await get_tree().process_frame
	# Leak check: once warmed up, pools must stop creating nodes. Leaked (never returned) items
	# would force them to keep growing for the whole run.
	var growth: int = PoolManager.total_created() - created_mark
	print("=== TRACK SOAK ===")
	print("simulated %.0f s, distance %.0f m, chunks recycled %d" % [SIM_SECONDS,
			track.distance_travelled, track.recycled_count])
	print("max gap %.6f m, chunk count constant: %s, pool growth after warm-up: %d, peak in use %d" % [
			track.max_gap_seen, count_ok, growth, in_use_peak])
	print("validator rejects %d, pools in use %d / created %d" % [track.generator.failures,
			PoolManager.total_in_use(), PoolManager.total_created()])
	var ok: bool = track.max_gap_seen <= 0.01 and count_ok and growth <= 4
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
