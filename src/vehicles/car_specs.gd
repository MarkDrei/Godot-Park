class_name CarSpecs
extends RefCounted
## Vehicle kinds of the Oststadt: size, driving behaviour and German names.
## Speeds in m/s (14 m/s ≈ 50 km/h), accelerations in m/s², steer in radians.

const KINDS := {
	"small": {"name": "Kleinwagen", "length": 3.9, "width": 1.75, "height": 1.5, "wheelbase": 2.45,
		"max": 15.0, "reverse": 5.0, "accel": 5.5, "brake": 11.0, "steer": 0.62, "open": false},
	"kombi": {"name": "Kombi", "length": 4.6, "width": 1.82, "height": 1.5, "wheelbase": 2.75,
		"max": 15.5, "reverse": 5.0, "accel": 5.0, "brake": 11.0, "steer": 0.58, "open": false},
	"van": {"name": "Lieferwagen", "length": 5.2, "width": 2.0, "height": 2.3, "wheelbase": 3.2,
		"max": 13.0, "reverse": 4.5, "accel": 3.8, "brake": 9.5, "steer": 0.55, "open": false},
	"taxi": {"name": "Taxi", "length": 4.7, "width": 1.82, "height": 1.5, "wheelbase": 2.8,
		"max": 15.5, "reverse": 5.0, "accel": 5.2, "brake": 11.0, "steer": 0.58, "open": false},
	"tow": {"name": "Abschleppwagen", "length": 6.4, "width": 2.2, "height": 2.6, "wheelbase": 3.8,
		"max": 12.0, "reverse": 4.0, "accel": 3.4, "brake": 9.0, "steer": 0.55, "open": false},
	"icecream": {"name": "Eiswagen", "length": 5.4, "width": 2.05, "height": 2.4, "wheelbase": 3.2,
		"max": 11.0, "reverse": 4.0, "accel": 3.4, "brake": 9.0, "steer": 0.55, "open": false},
	"garbage": {"name": "Müllwagen", "length": 7.6, "width": 2.45, "height": 3.1, "wheelbase": 4.4,
		"max": 10.0, "reverse": 3.5, "accel": 2.8, "brake": 8.0, "steer": 0.55, "open": false},
	"oldtimer": {"name": "Oldtimer", "length": 4.3, "width": 1.7, "height": 1.3, "wheelbase": 2.7,
		"max": 13.0, "reverse": 4.0, "accel": 4.0, "brake": 9.0, "steer": 0.55, "open": true},
	"kart": {"name": "Kart", "length": 2.0, "width": 1.25, "height": 0.6, "wheelbase": 1.3,
		"max": 13.5, "reverse": 3.5, "accel": 7.5, "brake": 13.0, "steer": 0.5, "open": true},
	"learner": {"name": "Fahrschulauto", "length": 4.0, "width": 1.75, "height": 1.5, "wheelbase": 2.5,
		"max": 15.0, "reverse": 5.0, "accel": 5.2, "brake": 11.0, "steer": 0.62, "open": false},
	"delivery": {"name": "Burger-Express", "length": 4.6, "width": 1.9, "height": 2.1, "wheelbase": 2.9,
		"max": 14.0, "reverse": 4.5, "accel": 4.6, "brake": 10.0, "steer": 0.58, "open": false},
}

## Colours of ordinary cars (parked and in traffic).
const COLORS := [Color("c0392b"), Color("2c3e50"), Color("ecf0f1"), Color("2e86de"), Color("7f8c8d"), Color("27ae60"),
	Color("f39c12"), Color("8e44ad"), Color("16a085"), Color("d35400"), Color("1f1f24"), Color("bdc3c7")]
const ORDINARY := ["small", "small", "kombi", "kombi", "van"]


static func spec(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS["small"])


static func name_of(kind: String) -> String:
	return spec(kind)["name"]


## km/h for the speedometer.
static func kmh(speed: float) -> int:
	return int(round(absf(speed) * 3.6))
