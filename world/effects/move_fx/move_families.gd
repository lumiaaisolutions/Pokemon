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

## Rayos rectos: [color (vacío = del tipo), ancho (m), duración (s), ondulado].
const BEAMS := {
	"ice-beam": ["a8e8ff", 0.35, 0.6, false], "hyper-beam": ["ffb050", 0.7, 0.9, false],
	"solar-beam": ["fff080", 0.6, 0.8, false], "psybeam": ["ff70c0", 0.3, 0.6, true],
	"aurora-beam": ["90f0ff", 0.35, 0.6, true], "signal-beam": ["c0ff60", 0.3, 0.6, true],
	"charge-beam": ["ffe030", 0.3, 0.5, false], "flash-cannon": ["e0e8f0", 0.5, 0.6, false],
	"dragon-pulse": ["7a5af0", 0.45, 0.6, true], "dark-pulse": ["3a2a40", 0.4, 0.6, true],
	"tri-attack": ["ffffff", 0.35, 0.5, false],
	"giga-impact": ["ffb050", 0.6, 0.6, false], "moongeist-beam": ["a070ff", 0.6, 0.9, false],
}
## Relámpagos: true = cae del cielo sobre el rival; false = sale del atacante.
const BOLTS := {"thunderbolt": false, "thunder-shock": false, "thunder": true, "zap-cannon": false, "discharge": false, "spark": false, "bolt-strike": true}
## Golpes y cortes: [forma, color (vacío = del tipo), golpes].
const MELEE := {
	"fire-punch": ["fist", "", 1], "ice-punch": ["fist", "", 1], "thunder-punch": ["fist", "", 1],
	"mach-punch": ["fist", "", 1], "mega-punch": ["fist", "", 1], "dynamic-punch": ["fist", "", 1],
	"focus-punch": ["fist", "", 1], "close-combat": ["fist", "", 4], 	"power-up-punch": ["fist", "", 1], "bullet-punch": ["fist", "", 1], "comet-punch": ["fist", "", 3],
	"drain-punch": ["fist", "", 1], "hammer-arm": ["fist", "", 1], "meteor-mash": ["fist", "", 1],
	"cross-chop": ["cross", "", 1], "x-scissor": ["cross", "", 1], "cross-poison": ["cross", "", 1],
	"karate-chop": ["slash", "", 1], "brick-break": ["slash", "", 1], "slash": ["slash", "", 1],
	"night-slash": ["slash", "", 1], "leaf-blade": ["slash", "", 1], "fury-cutter": ["slash", "", 2],
	"aerial-ace": ["slash", "", 1], "cut": ["slash", "", 1], "sacred-sword": ["slash", "", 1],
	"false-swipe": ["slash", "", 1], "psycho-cut": ["slash", "", 1], "razor-shell": ["slash", "", 1],
	"dragon-claw": ["claw", "", 1], "shadow-claw": ["claw", "", 1], "metal-claw": ["claw", "", 1],
	"crush-claw": ["claw", "", 1], "scratch": ["claw", "", 1], "fury-swipes": ["claw", "", 3],
	"double-hit": ["slash", "", 2],
}
## Desde el cielo: [forma, cantidad, marca en el suelo].
const SKY := {
	"rock-slide": ["rock", 5, "crack"], "draco-meteor": ["meteor", 4, "scorch"], "rock-throw": ["rock", 2, ""],
	"hail": ["icicle", 6, ""], "icicle-crash": ["icicle", 4, "crack"], "stone-edge": ["spike", 4, "crack"],
	"head-smash": ["rock", 3, "crack"],
}
## Suelo: onda expansiva (Terremoto) u ola (Surf).
const GROUND := {
	"earthquake": "quake", "bulldoze": "quake", "stomping-tantrum": "quake",
	"earth-power": "quake", "fissure": "quake", "surf": "wave", "water-pledge": "wave", "sparkling-aria": "wave",
}
## Ráfagas: [forma, cantidad, dispersión (m), gira].
const GUSTS := {
	"razor-leaf": ["leaf", 6, 1.2, true], "magical-leaf": ["leaf", 5, 1.0, true], "leaf-storm": ["leaf", 14, 2.0, true],
	"pin-missile": ["needle", 4, 0.6, false], "bullet-seed": ["orb", 5, 0.6, false], "icicle-spear": ["icicle", 4, 0.6, false],
	"rock-blast": ["rock", 3, 0.6, false], "mud-shot": ["orb", 3, 0.5, false], "air-cutter": ["slash", 2, 0.8, false],
	"air-slash": ["slash", 1, 0.0, false], "gust": ["feather", 4, 1.0, true],
	"spike-cannon": ["needle", 4, 0.6, false],
}
## Remolinos sobre el rival (Tornado, Vendaval).
const TWISTERS := ["twister", "hurricane", "whirlpool", "sand-tomb", "leaf-tornado"]


# --- Lote 3 -------------------------------------------------------------------------

## Drenaje: orbes verdes del rival al atacante.
const DRAINS := ["absorb", "mega-drain", "giga-drain", "leech-life", "parabolic-charge", "draining-kiss", "oblivion-wing", "bitter-blade"]
## Psíquico (levanta al rival con ondas) y Fantasma (sale de la sombra, lengua, sombra que avanza).
const PSYCHIC := ["psychic", "confusion", "extrasensory", "psyshock", "stored-power", "psycho-boost", "expanding-force"]
const GHOST := {"shadow-punch": "punch", "lick": "lick", "shadow-sneak": "sneak", "astonish": "sneak", "hex": "sneak", "poltergeist": "sneak", "spirit-shackle": "sneak"}
## Hada y Hielo: [modo, color].
const FAIRY_ICE := {
	"dazzling-gleam": ["gleam", "ffa8d8"], "moonblast": ["moon", "ffb8e0"], "disarming-voice": ["gleam", "ffa8d8"],
	"blizzard": ["snow", "e8f6ff"], "icy-wind": ["snow", "c8ecff"], "powder-snow": ["snow", "ffffff"], "frost-breath": ["snow", "c8ecff"],
	"ice-shard": ["icicle", "a8e8ff"], "fairy-wind": ["gleam", "ffc8e8"], "play-rough": ["gleam", "ff90c8"],
}
## Auras de carga: embiste cubierto del color del tipo y deja estela.
const CHARGES := ["flare-blitz", "wild-charge", "aqua-jet", "brave-bird", "quick-attack", "extreme-speed",
		"flame-charge", "take-down", "head-charge", "wave-crash", "accelerock", "zen-headbutt", "iron-head", "dragon-rush", "gyro-ball", "rollout", "steel-roller"]
## Saltos aplastantes: salta alto y cae sobre el rival con onda en el suelo.
const SLAMS := ["body-slam", "high-jump-kick", "jump-kick", "stomp", "heavy-slam", "heat-crash", "double-edge", "crabhammer", "dragon-hammer", "wood-hammer", "ice-hammer"]
## Explosiones: estallido en anillo con humo (alcanza a todos cerca).
const EXPLOSIONS := ["explosion", "self-destruct", "misty-explosion", "lava-plume", "sludge-wave", "mind-blown", "steam-eruption"]
## Sonido: ondas en arco y notas del atacante al rival.
const SOUNDS := ["hyper-voice", "boomburst", "bug-buzz", "round", "uproar", "snarl", "echoed-voice", "overdrive", "clanging-scales", "relic-song"]
## Ida y vuelta: golpea y vuelve a la ball; sale otro de tu equipo.
const UTURNS := ["u-turn", "volt-switch", "flip-turn"]
## Firmas de legendarios.
const SIGNATURES := ["aeroblast", "roar-of-time", "spacial-rend", "origin-pulse", "precipice-blades", "dragon-ascent", "sacred-fire", "judgment", "blue-flare", "fusion-flare", "fusion-bolt"]
## Definitivos de los iniciales.
const ULTIMATES := ["frenzy-plant", "blast-burn", "hydro-cannon"]
## Multigolpe que reutiliza golpes y cortes (se suman a MELEE).
const MULTI := {"double-slap": ["fist", "", 3], "fury-attack": ["slash", "", 3], "arm-thrust": ["fist", "", 4], "double-kick": ["fist", "", 2], "triple-kick": ["fist", "", 3]}

## Ataques de estado con animación: modo.
const STATUS := {
	# Mejoras.
	"swords-dance": "swords", "nasty-plot": "aura", "calm-mind": "aura", "bulk-up": "aura", "dragon-dance": "aura",
	"work-up": "aura", "growth": "aura", "iron-defense": "aura", "amnesia": "aura", "shell-smash": "aura", "quiver-dance": "aura",
	"coil": "aura", "hone-claws": "aura", "agility": "speed", "rock-polish": "speed", "autotomize": "speed",
	"protect": "shield", "detect": "shield", "kings-shield": "shield", "spiky-shield": "shield", "baneful-bunker": "shield", "reflect": "shield", "light-screen": "shield",
	# Clima y terreno.
	"rain-dance": "rain", "sunny-day": "sun", "hail": "hail", "snowscape": "hail", "sandstorm": "sand",
	"grassy-terrain": "terrain", "electric-terrain": "terrain", "misty-terrain": "terrain", "psychic-terrain": "terrain",
	# Estados alterados.
	"poison-powder": "powder", "sleep-powder": "powder", "stun-spore": "powder", "spore": "powder", "toxic": "powder",
	"thunder-wave": "zap", "will-o-wisp": "wisp", "hypnosis": "waves", "confuse-ray": "wisp", "glare": "eyes", "sing": "notes",
	"yawn": "waves", "supersonic": "waves", "sweet-kiss": "hearts",
	# Trampas.
	"spikes": "hazard", "stealth-rock": "hazard", "toxic-spikes": "hazard", "sticky-web": "hazard",
	# Bajar estadísticas y copias.
	"leer": "eyes", "growl": "waves", "charm": "hearts", "scary-face": "eyes", "tail-whip": "waves", "screech": "waves",
	"fake-tears": "waves", "baby-doll-eyes": "hearts", "feather-dance": "feathers", "string-shot": "web-shot",
	"double-team": "clones", "substitute": "doll", "transform": "transform", "minimize": "speed",
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
	if BEAMS.has(id):
		return "beam"
	if BOLTS.has(id):
		return "bolt"
	if MELEE.has(id):
		return "melee"
	if SKY.has(id):
		return "sky"
	if GROUND.has(id):
		return "ground"
	if GUSTS.has(id):
		return "gust"
	if TWISTERS.has(id):
		return "twister"
	if MULTI.has(id):
		return "melee"
	if DRAINS.has(id):
		return "drain"
	if PSYCHIC.has(id):
		return "psychic"
	if GHOST.has(id):
		return "ghost"
	if FAIRY_ICE.has(id):
		return "fairy_ice"
	if CHARGES.has(id):
		return "charge"
	if SLAMS.has(id):
		return "slam"
	if EXPLOSIONS.has(id):
		return "explosion"
	if SOUNDS.has(id):
		return "sound"
	if UTURNS.has(id):
		return "uturn"
	if SIGNATURES.has(id):
		return "signature"
	if ULTIMATES.has(id):
		return "ultimate"
	return ""


## Modo de la animación de un ataque de estado ("" si no tiene).
static func status_mode(id: String) -> String:
	return String(STATUS.get(id, ""))


## Ataque fuerte (temblor, destello y marca en el suelo): potencia 90 o más.
static func strong(id: String) -> bool:
	return int(Moves.get_move(id).get("power", 0)) >= 90


static func color_of(id: String, html: String) -> Color:
	if html != "":
		return Color.html(html)
	return AttackProjectile.TYPE_COLORS.get(int(Moves.get_move(id)["type"]), Color.WHITE)
