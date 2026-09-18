extends Resource
class_name WorldDatabase
## The explicit list of worlds, in order.
##
## Replaces scanning res://resources/worlds/ with DirAccess. Two reasons that
## scan had to go:
##
##   1. It broke on export. Godot rewrites some packed resources as .remap, so
##      a filter on ".tres" silently finds nothing and the map comes up empty —
##      in the exported build only, never in the editor.
##   2. It loaded anything ending in .tres, including planet SpriteFrames that
##      happen to live in the same folder, as if it were a WorldData.
##
## An explicit list also makes the order deliberate rather than alphabetical,
## and makes a missing world a visible blank in the Inspector.

const DEFAULT_PATH := "res://resources/worlds/world_database.tres"

@export var worlds: Array[WorldData] = []


## The project's one database. Cached, so repeated lookups cost nothing.
static var _default: WorldDatabase

static func load_default() -> WorldDatabase:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default


## Worlds in play order, skipping any empty slot left in the array.
func in_order() -> Array[WorldData]:
	var out: Array[WorldData] = []
	for w in worlds:
		if w != null:
			out.append(w)
	out.sort_custom(func(a, b): return a.order_index < b.order_index)
	return out


func by_id(world_id: String) -> WorldData:
	for w in worlds:
		if w != null and w.world_id == world_id:
			return w
	return null
