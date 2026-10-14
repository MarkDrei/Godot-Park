class_name Materials
extends RefCounted
## Shared materials, keyed by MeshKit surface name.

const SOLID := preload("res://src/shaders/solid.gdshader")
const FOLIAGE := preload("res://src/shaders/foliage.gdshader")
const GROUND := preload("res://src/shaders/ground.gdshader")
const GLOW := preload("res://src/shaders/glow.gdshader")
const WATER := preload("res://src/shaders/water.gdshader")
const SURFACE := preload("res://src/shaders/surface.gdshader")
const FAIR := preload("res://src/shaders/fair.gdshader")
const FAIR_LIGHTS := preload("res://src/shaders/fair_lights.gdshader")
const CAR := preload("res://src/shaders/car.gdshader")
## Surface patterns of the surface shader (paths, curbs, bridges).
const PATTERNS := ["paved", "gravel", "earth", "curb", "planks", "cobbles", "masonry", "rings", "bark", "asphalt"]
## Finishes of the fair shader (booths, rides): painted boards, canvas (flutters where the vertex
## alpha is below 1) and lacquer (metal where the vertex alpha is 0) with a sky reflection.
const FAIR_FINISHES := ["boards", "canvas", "lacquer"]

static var _cache := {}


static func get_material(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var mat: Material
	match name:
		"solid":
			mat = _shader(SOLID)
		"nosnow":
			mat = _shader(SOLID, {"snow_factor": 0.0})
		"foliage":
			mat = _shader(FOLIAGE, {"leaf_pattern": 1})
		"cherry":
			mat = _shader(FOLIAGE, {"blossoms": true, "leaf_pattern": 1})
		"evergreen":
			mat = _shader(FOLIAGE, {"deciduous": false, "seasonal": false, "sway": 0.5, "leaf_pattern": 2})
		"grass":
			mat = _shader(FOLIAGE, {"deciduous": false, "sway": 2.0, "grass_tinted": true})
		"flower":
			mat = _shader(FOLIAGE, {"deciduous": true, "seasonal": false, "sway": 2.0})
		"ground":
			mat = _shader(GROUND)
		"glow":
			mat = _shader(GLOW)
		"water":
			mat = _shader(WATER)
		"bulbs":
			mat = _shader(FAIR_LIGHTS)
		"car":
			mat = _shader(CAR)
		"character":
			var std := StandardMaterial3D.new()
			std.vertex_color_use_as_albedo = true
			std.roughness = 0.85
			mat = std
		"unshaded":
			var un := StandardMaterial3D.new()
			un.vertex_color_use_as_albedo = true
			un.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat = un
		_ when name in PATTERNS:
			mat = _shader(SURFACE, {"pattern": PATTERNS.find(name)})
		_ when name in FAIR_FINISHES:
			mat = _shader(FAIR, {"pattern": FAIR_FINISHES.find(name)})
		_:
			push_warning("Unknown material '%s', using solid" % name)
			mat = _shader(SOLID)
	_cache[name] = mat
	return mat


static func _shader(shader: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return m
