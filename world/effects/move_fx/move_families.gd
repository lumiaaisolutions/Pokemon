class_name MoveFamilies
extends RefCounted
## Qué animación usa cada ataque (familias acordadas con Fernando el 2026-10-10, ver
## docs/sistemas/animaciones_ataques.md). Cada familia sirve a varios ataques; los que no
## tienen familia usan la animación de siempre (embestida o proyectil del tipo).

## Se meten y salen bajo el rival: modo (bajo tierra, bajo el agua, por el cielo o se esfuma).
const BURROW := {
	"dig": "ground", "dive": "water", "fly": "sky", "bounce": "sky",
	"phantom-force": "vanish", "shadow-force": "vanish",
}
## Proyectiles con forma: [forma, cantidad, tamaño de píxel, velocidad, color (vacío = del tipo)].
const SHAPED := {
	"water-shuriken": ["shuriken", 3, 0.05, 16.0, ""],
	"fire-blast": ["fire_star", 1, 0.09, 11.0, ""],
	"shadow-ball": ["orb", 1, 0.08, 12.0, ""],
	"aura-sphere": ["orb", 1, 0.08, 14.0, ""],
	"energy-ball": ["orb", 1, 0.08, 12.0, ""],
	"sludge-bomb": ["orb", 1, 0.07, 12.0, ""],
	"focus-blast": ["orb", 1, 0.1, 10.0, ""],
	"weather-ball": ["orb", 1, 0.08, 12.0, ""],
	"seed-bomb": ["orb", 1, 0.06, 13.0, ""],
	"electro-ball": ["orb", 1, 0.07, 15.0, ""],
}
## Chorros: [forma de cada gota, color (vacío = del tipo), duración (s)].
const STREAM := {
	"flamethrower": ["flame", "", 0.8], "ember": ["flame", "", 0.35], "fire-spin": ["flame", "", 0.8],
	"overheat": ["flame", "", 1.0], "heat-wave": ["flame", "", 0.9], "inferno": ["flame", "", 1.0],
	"water-gun": ["drop", "", 0.45], "hydro-pump": ["drop", "", 0.9], "bubble-beam": ["orb", "", 0.6],
	"bubble": ["orb", "", 0.4], "scald": ["drop", "", 0.6], "muddy-water": ["drop", "a07850", 0.7],
	"sludge": ["orb", "", 0.5], "acid": ["drop", "a050c8", 0.4], "mud-slap": ["drop", "8c6438", 0.3],
	"dragon-breath": ["flame", "7a5af0", 0.6], "poison-gas": ["orb", "", 0.6],
}
## Lianas que salen del atacante y azotan al rival.
const VINES := ["vine-whip", "power-whip", "wrap", "bind", "grass-knot", "horn-leech"]
## Mordidas: color de los colmillos (vacío = blancos).
const BITES := {
	"bite": "", "crunch": "", "hyper-fang": "", "super-fang": "", "jaw-lock": "",
	"fire-fang": "ff7a20", "ice-fang": "a8e8ff", "thunder-fang": "ffe030", "poison-fang": "b050d0",
	"psychic-fangs": "ff70b0", "fishious-rend": "70b0ff",
}


## Familia del ataque ("" si no tiene: animación de siempre).
static func family(id: String) -> String:
	if BURROW.has(id):
		return "burrow"
	if SHAPED.has(id):
		return "shaped"
	if STREAM.has(id):
		return "stream"
	if VINES.has(id):
		return "vines"
	if BITES.has(id):
		return "bite"
	return ""


## Ataque fuerte (temblor, destello y marca en el suelo): potencia 90 o más.
static func strong(id: String) -> bool:
	return int(Moves.get_move(id).get("power", 0)) >= 90


static func color_of(id: String, html: String) -> Color:
	if html != "":
		return Color.html(html)
	return AttackProjectile.TYPE_COLORS.get(int(Moves.get_move(id)["type"]), Color.WHITE)
