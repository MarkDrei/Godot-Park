class_name Potions
extends RefCounted
## The potions of the Ritterburg (doc/burg.md): brewed by the herb witch and the alchemist from
## herbs and berries (Crafting, a fee), drunk from the bag. Each works for HOURS game hours on
## whoever the player controls; a second one of the same kind starts the hours anew. The buffs
## are saved (GameState.buffs: id -> game hour it ends).
##   speed:  walk and run 50 % faster, no fatigue from walking or running (Actor)
##   herbs:  twice the herbs and berries when picking (Gathering)
##   mining: felling trees and mining stones twice as fast (Gathering)

const HOURS := 8.0
const SPEED := 1.5
## Potion item -> buff.
const BUFFS := {"potion_speed": "speed", "potion_herbs": "herbs", "potion_mining": "mining"}
const NAMES := {"speed": "Lauftrank", "herbs": "Kräutertrank", "mining": "Abbautrank"}
const EFFECTS := {"speed": "Du läufst schneller und wirst vom Laufen nicht müde.",
	"herbs": "Du pflückst doppelt so viele Kräuter und Beeren.",
	"mining": "Bäume und Steine baust du doppelt so schnell ab."}


static func is_potion(item: String) -> bool:
	return BUFFS.has(item)


static func active(buff: String) -> bool:
	return hours_left(buff) > 0.0


static func hours_left(buff: String) -> float:
	return maxf(0.0, float(GameState.buffs.get(buff, 0.0)) - Gathering.now())


## Drinks a potion from the actor's bag: the buff runs for HOURS from now.
static func drink(a: Actor, item: String) -> bool:
	if not is_potion(item) or not a.take_item(item):
		return false
	var buff: String = BUFFS[item]
	GameState.buffs[buff] = Gathering.now() + HOURS
	a.play_anim("drink", 1.5)
	a.needs.cheer(4.0)
	GameState.add_to_set("potions_drunk", buff)
	GameState.toast.emit("%s wirkt %d Stunden: %s" % [NAMES[buff], int(HOURS), EFFECTS[buff]], "info")
	Sound.play("pickup", a.global_position)
	return true


## The running potions as a short line for the HUD ("Lauftrank 5 h"), "" if none.
static func hud_line() -> String:
	var out := []
	for buff: String in NAMES:
		var h := hours_left(buff)
		if h > 0.0:
			out.append("%s %s" % [NAMES[buff], ("%d h" % ceili(h)) if h >= 1.0 else ("%d min" % ceili(h * 60.0))])
	return " · ".join(out)


## Speed factor for the player (Actor._speed_boost).
static func speed_factor(a: Actor) -> float:
	return SPEED if a.controlled and active("speed") else 1.0
