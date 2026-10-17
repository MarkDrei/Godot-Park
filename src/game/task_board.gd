class_name TaskBoard
extends RefCounted
## Collects the open jobs and quests for the "Aufgaben" screen.
## Providers: func() -> Array of {"title", "desc", "done": bool, "active": bool, "area"}; "area"
## is a key of TasksScreen.AREAS (default "park"), the notebook filters by it.

static var providers: Array[Callable] = []


static func register(provider: Callable) -> void:
	providers.append(provider)


static func entries() -> Array:
	var out := []
	for p in providers:
		out.append_array(p.call())
	return out
