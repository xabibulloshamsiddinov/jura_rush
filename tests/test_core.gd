## Unit tests: StateMachine, ObjectPool, SaveSystem / SaveCodec, score maths, difficulty curve,
## purchase rollback.
extends TestCase


class CountingState extends State:
	var entered: int = 0
	var exited: int = 0

	func enter(_prev: StringName) -> void:
		entered += 1

	func exit(_next: StringName) -> void:
		exited += 1


class PoolItem extends Node:
	var acquired: int = 0
	var released: int = 0

	func on_acquire() -> void:
		acquired += 1

	func on_release() -> void:
		released += 1


## Save stand-in whose save_game() can be made to fail (tests the purchase rollback).
class FakeSave extends RefCounted:
	var coin_balance: int = 1000
	var owned: Array[StringName] = []
	var fail_save: bool = false

	func owns(id: StringName) -> bool:
		return owned.has(id)

	func spend(_currency: StringName, amount: int) -> bool:
		if coin_balance < amount:
			return false
		coin_balance -= amount
		return true

	func grant(id: StringName) -> void:
		owned.append(id)

	func revoke(id: StringName) -> void:
		owned.erase(id)

	func add_coins(amount: int) -> void:
		coin_balance += amount

	func upgrade_level(_id: StringName) -> int:
		return 1

	func save_game() -> bool:
		return not fail_save


func test_state_machine_transitions() -> void:
	var machine: StateMachine = StateMachine.new()
	var a: CountingState = CountingState.new()
	var b: CountingState = CountingState.new()
	machine.add_state(&"a", a, self)
	machine.add_state(&"b", b, self)
	machine.add_state(&"c", CountingState.new(), self)
	machine.allow(&"b", [&"a"])
	machine.start(&"a")
	check_eq(machine.current_id, &"a", "starts in a")
	check(machine.transition_to(&"b"), "a -> b allowed")
	check_eq(a.exited, 1, "a exited once")
	check_eq(b.entered, 1, "b entered once")
	check(not machine.transition_to(&"c"), "b -> c blocked by whitelist")
	check(not machine.transition_to(&"zzz"), "unknown state rejected")
	check(not machine.transition_to(&"b"), "re-enter rejected by default")
	check(machine.transition_to(&"a"), "b -> a allowed")
	check_eq(machine.previous_id, &"b", "previous id tracked")
	machine.free()


func test_object_pool_counts() -> void:
	var pool: ObjectPool = ObjectPool.new(&"t", null, func() -> Node: return PoolItem.new(), 3)
	check_eq(pool.created, 3, "pre-warmed 3")
	var items: Array[Node] = []
	for i in range(5):
		items.append(pool.acquire())
	check_eq(pool.created, 5, "grew to 5")
	check_eq(pool.in_use, 5, "5 in use")
	for item in items:
		pool.release(item)
	pool.release(items[0])
	check_eq(pool.in_use, 0, "all returned, double release ignored")
	check_eq(pool.free_count(), 5, "5 idle")
	var again: PoolItem = pool.acquire() as PoolItem
	check_eq(pool.created, 5, "reuse does not create")
	check_eq(again.acquired, 2, "on_acquire called on reuse")
	check_eq(again.released, 1, "on_release called once")
	pool.release(again)
	pool.dispose()


func test_save_roundtrip() -> void:
	var data: Dictionary = SaveCodec.defaults()
	data["coins"] = 777
	data["owned"] = ["volt", "cyan", "ember"]
	var decoded: Dictionary = SaveCodec.decode(SaveCodec.encode(data))
	check_eq(int(decoded.get("coins", 0)), 777, "coins survive roundtrip")
	check_eq((decoded.get("owned", []) as Array).size(), 3, "owned list survives")


func test_save_migration_v1_to_v2() -> void:
	var v1: Dictionary = {"save_version": 1, "coins": 50, "best": 1234, "skins": ["moss"], "skin": "moss"}
	var v2: Dictionary = SaveCodec.migrate(v1)
	check_eq(int(v2["save_version"]), SaveCodec.VERSION, "version bumped")
	check_eq(int(v2["best_score"]), 1234, "best -> best_score")
	check(not v2.has("best") and not v2.has("skins"), "old keys removed")
	check((v2["owned"] as Array).has("moss"), "skins -> owned")
	check_eq(str((v2["equipped"] as Dictionary)["character"]), "moss", "skin -> equipped.character")
	check(v2.has("missions") and v2.has("keys"), "new sections filled from defaults")


func test_save_corruption_recovery() -> void:
	var path: String = "user://test_save.json"
	var save: Node = (load("res://scripts/autoload/save_system.gd") as GDScript).new()
	save.set(&"path", path)
	save.set(&"data", SaveCodec.defaults())
	(save.get(&"data") as Dictionary)["coins"] = 321
	check(bool(save.call(&"save_game")), "first save ok")
	(save.get(&"data") as Dictionary)["coins"] = 654
	check(bool(save.call(&"save_game")), "second save ok (backup written)")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not a valid save")
	file.close()
	save.call(&"load_game")
	check_eq(str(save.get(&"last_load_source")), "backup", "falls back to the backup")
	check_eq(int((save.get(&"data") as Dictionary)["coins"]), 321, "backup holds the previous save")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	save.call(&"load_game")
	check_eq(str(save.get(&"last_load_source")), "defaults", "no files -> defaults")
	check(SaveCodec.decode(SaveCodec.encode(SaveCodec.defaults()).replace("volt", "hack")).is_empty(),
			"tampered payload fails the checksum")
	save.free()


func test_score_calculation() -> void:
	var cfg: GameConfig = GameConfig.current()
	check_eq(ScoreCalculator.run_total(1000.0, 50, 4, cfg, 1), 1000 + 500 + 200, "base formula")
	check_eq(ScoreCalculator.run_total(1000.0, 50, 4, cfg, 3), 5100, "multiplier applies to all")
	check_near(ScoreCalculator.points(50.0, 3, 2, 4), 1200.0, 0.001, "points = base*combo*x2*account")
	check_eq(ScoreCalculator.combo_level(0, 0, 5), 1, "no chain = x1")
	check_eq(ScoreCalculator.combo_level(2, 25, 5), 5, "2 near + 25 coins = x5")
	check_eq(ScoreCalculator.combo_level(9, 90, 5), 5, "combo capped")


func test_difficulty_monotonic() -> void:
	var cfg: GameConfig = GameConfig.current()
	for id: StringName in [&"linear", &"curve", &"adaptive"]:
		var strategy: DifficultyStrategy = DifficultyStrategy.create(id)
		var last: float = -1.0
		var ok: bool = true
		for i in range(0, 361):
			var f: float = strategy.speed_fraction(float(i), cfg)
			if f < last - 0.0001 or f < 0.0 or f > 1.0:
				ok = false
			last = f
		check(ok, "%s speed fraction is monotonic and within 0..1" % id)
		check_near(strategy.speed_fraction(cfg.speed_ramp_time, cfg), 1.0, 0.01, "%s reaches max" % id)
	check_near(cfg.jump_height_at_time(cfg.jump_up_time(0.0), 0.0), cfg.jump_height, 0.01, "jump apex")
	check_near(cfg.jump_height_at_time(cfg.jump_time, 0.0), 0.0, 0.02, "jump lands after jump_time")


func test_purchase_rollback() -> void:
	var save: FakeSave = FakeSave.new()
	var buy: PurchaseCommand = PurchaseCommand.new(&"item", &"ember")
	check(buy.execute(save), "purchase succeeds")
	check_eq(save.coin_balance, 500, "coins deducted")
	check(save.owns(&"ember"), "item granted")
	check(not PurchaseCommand.new(&"item", &"ember").execute(save), "cannot buy twice")
	save.fail_save = true
	var failing: PurchaseCommand = PurchaseCommand.new(&"item", &"cyan")
	save.coin_balance = 5000
	var pricey: PurchaseCommand = PurchaseCommand.new(&"item", &"moss")
	check(not pricey.execute(save), "failed save reports failure")
	check_eq(pricey.failure, &"save", "failure reason is save")
	check_eq(save.coin_balance, 5000, "coins refunded on rollback")
	check(not save.owns(&"moss"), "item revoked on rollback")
	save.coin_balance = 10
	save.fail_save = false
	check(not PurchaseCommand.new(&"item", &"onyx").execute(save), "too poor")
	check(failing.failure == &"", "untouched command has no failure")
