class_name FairMap
extends RefCounted
## Writes the Westpark (FairLayout) into the ParkMap when it is loaded (World.load_fair): the
## pond, heights with hills and levelled plazas, paths and ground kinds of its cells. The same
## rules as the city park (ParkMap), only with the Westpark's data.


static func build(map: ParkMap) -> void:
	map.raster_pond(FairLayout.POND_CENTER, FairLayout.POND_RADII)
	var flats := []
	for key: String in FairLayout.PLAZAS:
		var pl: Dictionary = FairLayout.PLAZAS[key]
		flats.append([pl["pos"], float(pl["r"]), 4.0, ParkMap.base_height(pl["pos"])])
	for key: String in FairLayout.AREAS:
		var area: Dictionary = FairLayout.AREAS[key]
		flats.append([area["pos"], (area["size"] as Vector2).length() * 0.5, 4.0, ParkMap.base_height(area["pos"])])
	# Vertex column PARK_X0 lies on the fence and belongs to the park.
	map.compute_heights(0, ParkMap.PARK_X0 - 1, ParkMap.FAIR_Z0, ParkMap.H, flats)
	var polys := FairLayout.path_polylines()
	map.paths.append_array(polys)
	map.raster_paths(polys, 0, ParkMap.PARK_X0)
	map.compute_ground(0, ParkMap.PARK_X0, ParkMap.FAIR_Z0, ParkMap.H, FairLayout.AREAS, FairLayout.PLAZAS)
	map.fair_ready = true


## The Westpark's paths (the smoothed polylines in map.paths).
static func paths(map: ParkMap) -> Array:
	return map.paths.filter(func(p: Dictionary) -> bool: return (p["id"] as String).begins_with("fair_"))
