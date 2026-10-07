class_name TaskBoard
extends RefCounted
## Collects the open jobs and quests for the "Aufgaben" screen.
## Providers: func() -> Array of {"title", "desc", "done": bool}.

static var providers: Array[Callable] = []


static func register(provider: Callable) -> void:
	providers.append(provider)


static func entries() -> Array:
	var out := []
	for p in providers:
		out.append_array(p.call())
	return out
