## Base class of every UI screen. Screens build their nodes once in build(), refresh in
## on_enter(), and only talk to the game through GameEvents / services.
class_name UIScreen
extends Control

## Popups keep the screen underneath visible (pause, revive).
var is_popup: bool = false
## Arguments passed by the router on the last show / push.
var args: Dictionary = {}

var _built: bool = false


func _ready() -> void:
	UIKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	connect_events()
	ensure_built()


## Subscribes to GameEvents. Called exactly once (build() may run again on rebuild()).
func connect_events() -> void:
	pass


## Builds the node tree the first time it is needed.
func ensure_built() -> void:
	if not _built:
		_built = true
		build()


## Destroys and rebuilds the node tree (language or text-size change).
func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build()
	if visible:
		on_enter(args)


## Creates the screen's controls. Called once.
func build() -> void:
	pass


## Called every time the screen is shown.
func on_enter(_args: Dictionary) -> void:
	pass


## Called when the screen is hidden.
func on_exit() -> void:
	pass


## Back button / Esc. Return true when handled; false lets the router pop the screen.
func handle_back() -> bool:
	return false


## Shortcut for translations.
func tr_key(key: StringName) -> String:
	return Tr.t(key)


## Adds `node` pinned to an anchor point (0..1 of the screen) plus a pixel offset. The node keeps
## its minimum size and grows from the point in the given directions (BEGIN = left / up,
## END = right / down, BOTH = centred). Containers placed this way ignore the mouse.
func place(node: Control, anchor: Vector2, offset: Vector2, grow_h: Control.GrowDirection,
		grow_v: Control.GrowDirection) -> void:
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = offset.x
	node.offset_right = offset.x
	node.offset_top = offset.y
	node.offset_bottom = offset.y
	node.grow_horizontal = grow_h
	node.grow_vertical = grow_v
	if node is Container:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
