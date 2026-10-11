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
	# Reasignados (2026-10-10).
	"egg-bomb": ["orb", 1, 0.08, 11.0, "fff0c0"], "hidden-power": ["orb", 1, 0.06, 13.0, ""], "pyro-ball": ["fire_star", 1, 0.07, 12.0, ""], "mist-ball": ["orb", 1, 0.08, 12.0, "ffc0e0"], "luster-purge": ["orb", 1, 0.08, 12.0, "a0c0ff"], "flame-burst": ["orb", 1, 0.07, 13.0, ""], "searing-shot": ["fire_star", 1, 0.06, 13.0, ""], "octazooka": ["orb", 1, 0.07, 13.0, "404060"], "water-pulse": ["orb", 1, 0.08, 12.0, ""], "brine": ["orb", 1, 0.07, 12.0, ""], "syrup-bomb": ["orb", 1, 0.07, 12.0, "c86030"], "apple-acid": ["orb", 1, 0.07, 12.0, "90d040"], "pollen-puff": ["orb", 1, 0.08, 11.0, "ffe080"], "gunk-shot": ["orb", 1, 0.09, 12.0, ""], "smack-down": ["rock", 1, 0.08, 14.0, "a09070"], "armor-cannon": ["fire_star", 1, 0.08, 12.0, ""], "fling": ["rock", 1, 0.06, 14.0, "c0c0c0"], "pay-day": ["star", 3, 0.05, 14.0, "ffd040"], "sonic-boom": ["orb", 1, 0.06, 15.0, "e0e0ff"], "dragon-rage": ["orb", 1, 0.08, 12.0, "7a5af0"], "spit-up": ["orb", 1, 0.07, 12.0, ""], "natural-gift": ["orb", 1, 0.06, 13.0, ""], "present": ["orb", 1, 0.06, 12.0, "ff6060"]
}
## Chorros: [forma de cada gota, color (vacío = del tipo), duración (s)].
const STREAM := {
	"flamethrower": ["flame", "", 0.8], "ember": ["flame", "", 0.35], "fire-spin": ["flame", "", 0.8],
	"overheat": ["flame", "", 1.0], "heat-wave": ["flame", "", 0.9], "inferno": ["flame", "", 1.0],
	"water-gun": ["drop", "", 0.45], "hydro-pump": ["drop", "", 0.9], "bubble-beam": ["orb", "", 0.6],
	"bubble": ["orb", "", 0.4], "scald": ["drop", "", 0.6], "muddy-water": ["drop", "a07850", 0.7],
	"sludge": ["orb", "", 0.5], "acid": ["drop", "a050c8", 0.4], "mud-slap": ["drop", "8c6438", 0.3],
	"dragon-breath": ["flame", "7a5af0", 0.6], "poison-gas": ["orb", "", 0.6],
	# Reasignados (2026-10-10).
	"smog": ["orb", "", 0.6], "clear-smog": ["orb", "e0e0e0", 0.5], "acid-spray": ["drop", "a050c8", 0.4], "belch": ["orb", "a060c0", 0.6], "hydro-steam": ["drop", "", 0.8], "chilling-water": ["drop", "a8e8ff", 0.5], "water-spout": ["drop", "", 1.0], "fire-pledge": ["flame", "", 0.7], "incinerate": ["flame", "", 0.5], "burn-up": ["flame", "", 1.0], "burning-jealousy": ["flame", "", 0.6], "mystical-fire": ["flame", "c070ff", 0.6], "scorching-sands": ["orb", "d8b060", 0.5], "venoshock": ["drop", "a050c8", 0.5], "matcha-gotcha": ["drop", "80c040", 0.6], "dream-eater": ["orb", "ff70c0", 0.6]
}
## Lianas que salen del atacante y azotan al rival.
const VINES := ["vine-whip", "power-whip", "wrap", "bind", "grass-knot", "horn-leech",
		# Reasignados (2026-10-10).
		"grass-pledge", "malignant-chain", "fire-lash"
]
## Mordidas: color de los colmillos (vacío = blancos).
const BITES := {
	"bite": "", "crunch": "", "hyper-fang": "", "super-fang": "", "jaw-lock": "",
	"fire-fang": "ff7a20", "ice-fang": "a8e8ff", "thunder-fang": "ffe030", "poison-fang": "b050d0",
	"psychic-fangs": "ff70b0", "fishious-rend": "70b0ff",
	# Reasignados (2026-10-10).
	"bug-bite": "", "clamp": ""
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
	# Reasignados (2026-10-10).
	"steel-beam": ["e0e8f0", 0.6, 0.8, false], "prismatic-laser": ["ffffff", 0.7, 1.0, true], "meteor-beam": ["d0b080", 0.6, 0.9, false], "dynamax-cannon": ["ff4060", 0.7, 0.9, false], "dragon-energy": ["7a5af0", 0.8, 1.0, false], "fickle-beam": ["7a5af0", 0.4, 0.6, true], "core-enforcer": ["60e060", 0.5, 0.8, true], "twin-beam": ["ff70c0", 0.25, 0.5, false], "techno-blast": ["ffffff", 0.4, 0.6, false], "tera-blast": ["ffffff", 0.5, 0.7, false], "terrain-pulse": ["ffffff", 0.4, 0.6, true], "electro-shot": ["ffe030", 0.5, 0.7, false], "fleur-cannon": ["ff90c8", 0.7, 0.9, false], "snipe-shot": ["70b8ff", 0.2, 0.4, false], "night-shade": ["3a2a40", 0.4, 0.6, true], "photon-geyser": ["fff080", 0.7, 0.9, false], "psywave": ["ff70c0", 0.3, 0.6, true]
}
## Relámpagos: true = cae del cielo sobre el rival; false = sale del atacante.
const BOLTS := {"thunderbolt": false, "thunder-shock": false, "thunder": true, "zap-cannon": false, "discharge": false, "spark": false, "bolt-strike": true,
	# Reasignados (2026-10-10).
	"shock-wave": false, "thunderclap": false, "rising-voltage": true, "wildbolt-storm": true
}
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
	# Reasignados (2026-10-10).
	"dizzy-punch": ["fist", "", 1], "mega-kick": ["fist", "", 1], "force-palm": ["fist", "", 1], "rolling-kick": ["fist", "", 1], "low-kick": ["fist", "", 1], "low-sweep": ["fist", "", 1], "rock-smash": ["fist", "", 1], "axe-kick": ["fist", "", 1], "jet-punch": ["fist", "", 1], "plasma-fists": ["fist", "", 1], "rage-fist": ["fist", "", 1], "blaze-kick": ["fist", "", 1], "trop-kick": ["fist", "", 1], "double-iron-bash": ["fist", "", 2], "triple-axel": ["fist", "", 3], "pound": ["fist", "", 1], "vital-throw": ["fist", "", 1], "seismic-toss": ["fist", "", 1], "circle-throw": ["fist", "", 1], "storm-throw": ["fist", "", 1], "submission": ["fist", "", 1], "superpower": ["fist", "", 1], "revenge": ["fist", "", 1], "reversal": ["fist", "", 1], "counter": ["fist", "", 1], "upper-hand": ["fist", "", 1], "sucker-punch": ["fist", "", 1], "beat-up": ["fist", "", 3], "wicked-blow": ["fist", "", 1], "darkest-lariat": ["fist", "", 1], "lash-out": ["fist", "", 1], "payback": ["fist", "", 1], "comeuppance": ["fist", "", 1], "fake-out": ["fist", "", 1], "facade": ["fist", "", 1], "retaliate": ["fist", "", 1], "last-resort": ["fist", "", 1], "frustration": ["fist", "", 1], "return": ["fist", "", 1], "crush-grip": ["fist", "", 1], "ivy-cudgel": ["fist", "", 1], "poison-jab": ["fist", "", 1], "gear-grind": ["fist", "", 2], "hard-press": ["fist", "", 1], "order-up": ["fist", "", 1], "last-respects": ["fist", "", 1], "first-impression": ["fist", "", 1], "skitter-smack": ["fist", "", 1], "pounce": ["fist", "", 1], "lunge": ["fist", "", 1], "assurance": ["fist", "", 1], "feint": ["fist", "", 1], "covet": ["fist", "", 1], "false-surrender": ["fist", "", 1], "foul-play": ["fist", "", 1], "power-trip": ["fist", "", 1], "nuzzle": ["fist", "", 1], "endeavor": ["fist", "", 1], "flail": ["fist", "", 1], "rage": ["fist", "", 1], "bide": ["fist", "", 1], "stone-axe": ["slash", "", 1], "mighty-cleave": ["slash", "", 1], "psyblade": ["slash", "", 1], "solar-blade": ["slash", "", 1], "aqua-cutter": ["slash", "", 1], "kowtow-cleave": ["slash", "", 1], "secret-sword": ["slash", "", 1], "smart-strike": ["slash", "", 1], "steel-wing": ["slash", "", 1], "wing-attack": ["slash", "", 1], "dual-wingbeat": ["slash", "", 2], "breaking-swipe": ["slash", "", 1], "dragon-tail": ["slash", "", 1], "iron-tail": ["slash", "", 1], "poison-tail": ["slash", "", 1], "tail-slap": ["slash", "", 3], "knock-off": ["slash", "", 1], "fell-stinger": ["slash", "", 1], "branch-poke": ["slash", "", 1], "trailblaze": ["slash", "", 1], "flower-trick": ["slash", "", 1], "brutal-swing": ["slash", "", 1], "throat-chop": ["slash", "", 1], "spectral-thief": ["slash", "", 1], "dire-claw": ["claw", "", 1], "thief": ["claw", "", 1], "pluck": ["claw", "", 1], "vice-grip": ["claw", "", 1], "guillotine": ["cross", "", 1]
}
## Desde el cielo: [forma, cantidad, marca en el suelo].
const SKY := {
	"rock-slide": ["rock", 5, "crack"], "draco-meteor": ["meteor", 4, "scorch"], "rock-throw": ["rock", 2, ""],
	"hail": ["icicle", 6, ""], "icicle-crash": ["icicle", 4, "crack"], "stone-edge": ["spike", 4, "crack"],
	"head-smash": ["rock", 3, "crack"],
	# Reasignados (2026-10-10).
	"rock-tomb": ["rock", 4, "crack"], "ancient-power": ["rock", 3, ""], "thousand-arrows": ["spike", 6, "crack"], "eruption": ["meteor", 5, "scorch"], "tera-starstorm": ["orb", 5, "scorch"], "make-it-rain": ["star", 8, ""], "future-sight": ["orb", 1, ""], "doom-desire": ["orb", 1, "scorch"], "rock-wrecker": ["rock", 3, "crack"], "avalanche": ["icicle", 4, "crack"], "diamond-storm": ["spike", 5, "crack"], "seed-flare": ["orb", 3, "scorch"]
}
## Suelo: onda expansiva (Terremoto) u ola (Surf).
const GROUND := {
	"earthquake": "quake", "bulldoze": "quake", "stomping-tantrum": "quake",
	"earth-power": "quake", "fissure": "quake", "surf": "wave", "water-pledge": "wave", "sparkling-aria": "wave",
	# Reasignados (2026-10-10).
	"lands-wrath": "quake", "thousand-waves": "quake"
}
## Ráfagas: [forma, cantidad, dispersión (m), gira].
const GUSTS := {
	"razor-leaf": ["leaf", 6, 1.2, true], "magical-leaf": ["leaf", 5, 1.0, true], "leaf-storm": ["leaf", 14, 2.0, true],
	"pin-missile": ["needle", 4, 0.6, false], "bullet-seed": ["orb", 5, 0.6, false], "icicle-spear": ["icicle", 4, 0.6, false],
	"rock-blast": ["rock", 3, 0.6, false], "mud-shot": ["orb", 3, 0.5, false], "air-cutter": ["slash", 2, 0.8, false],
	"air-slash": ["slash", 1, 0.0, false], "gust": ["feather", 4, 1.0, true],
	"spike-cannon": ["needle", 4, 0.6, false],
	# Reasignados (2026-10-10).
	"swift": ["star", 5, 0.8, true], "power-gem": ["star", 3, 0.5, false], "barb-barrage": ["needle", 3, 0.5, false], "dragon-darts": ["orb", 2, 0.4, false], "scale-shot": ["orb", 4, 0.6, false], "poison-sting": ["needle", 1, 0.0, false], "attack-order": ["needle", 8, 1.2, false], "twineedle": ["needle", 2, 0.4, false], "silver-wind": ["feather", 6, 1.2, true], "petal-blizzard": ["leaf", 10, 1.8, true], "petal-dance": ["leaf", 10, 1.4, true], "leafage": ["leaf", 2, 0.4, true], "razor-wind": ["slash", 2, 0.8, false], "tachyon-cutter": ["slash", 2, 0.4, false], "bone-rush": ["rock", 3, 0.5, false], "bonemerang": ["rock", 2, 0.3, false], "bone-club": ["rock", 1, 0.0, false], "barrage": ["orb", 4, 0.6, false], "population-bomb": ["orb", 6, 0.8, false], "struggle-bug": ["needle", 4, 1.0, false], "electroweb": ["orb", 3, 0.8, false], "salt-cure": ["star", 4, 0.6, false], "mystical-power": ["orb", 3, 0.6, false], "lumina-crash": ["star", 5, 0.8, false], "anchor-shot": ["rock", 1, 0.0, false]
}
## Remolinos sobre el rival (Tornado, Vendaval).
const TWISTERS := ["twister", "hurricane", "whirlpool", "sand-tomb", "leaf-tornado",
		# Reasignados (2026-10-10).
		"magma-storm", "fiery-dance", "sandsear-storm", "infestation", "bleakwind-storm", "springtide-storm", "thunder-cage", "glaciate", "sheer-cold", "constrict"
]


# --- Lote 3 -------------------------------------------------------------------------

## Drenaje: orbes verdes del rival al atacante.
const DRAINS := ["absorb", "mega-drain", "giga-drain", "leech-life", "parabolic-charge", "draining-kiss", "oblivion-wing", "bitter-blade"]
## Psíquico (levanta al rival con ondas) y Fantasma (sale de la sombra, lengua, sombra que avanza).
const PSYCHIC := ["psychic", "confusion", "extrasensory", "psyshock", "stored-power", "psycho-boost", "expanding-force",
		# Reasignados (2026-10-10).
		"hyperspace-hole", "psychic-noise"
]
const GHOST := {"shadow-punch": "punch", "lick": "lick", "shadow-sneak": "sneak", "astonish": "sneak", "hex": "sneak", "poltergeist": "sneak", "spirit-shackle": "sneak"}
## Hada y Hielo: [modo, color].
const FAIRY_ICE := {
	"dazzling-gleam": ["gleam", "ffa8d8"], "moonblast": ["moon", "ffb8e0"], "disarming-voice": ["gleam", "ffa8d8"],
	"blizzard": ["snow", "e8f6ff"], "icy-wind": ["snow", "c8ecff"], "powder-snow": ["snow", "ffffff"], "frost-breath": ["snow", "c8ecff"],
	"ice-shard": ["icicle", "a8e8ff"], "fairy-wind": ["gleam", "ffc8e8"], "play-rough": ["gleam", "ff90c8"],
	# Reasignados (2026-10-10).
	"freeze-dry": ["snow", "c8ecff"], "spirit-break": ["gleam", "ff90c8"], "natures-madness": ["gleam", "ffa8d8"]
}
## Auras de carga: embiste cubierto del color del tipo y deja estela.
const CHARGES := ["flare-blitz", "wild-charge", "aqua-jet", "brave-bird", "quick-attack", "extreme-speed",
		"flame-charge", "take-down", "head-charge", "wave-crash", "accelerock", "zen-headbutt", "iron-head", "dragon-rush", "gyro-ball", "rollout", "steel-roller",
		# Reasignados (2026-10-10).
		"headbutt", "horn-attack", "skull-bash", "rapid-spin", "rock-climb", "tackle", "collision-course", "acrobatics", "drill-peck", "peck", "sky-attack", "beak-blast", "headlong-rush", "high-horsepower", "drill-run", "megahorn", "flame-wheel", "raging-fury", "temper-flare", "v-create", "aqua-step", "waterfall", "grassy-glide", "bolt-beak", "zing-zap", "aura-wheel", "double-shock", "psyshield-bash", "sunsteel-strike", "ice-spinner", "meteor-assault", "hyper-drill", "spin-out", "glaive-rush", "outrage", "thrash", "electro-drift", "horn-drill", "triple-dive", "mortal-spin"
]
## Saltos aplastantes: salta alto y cae sobre el rival con onda en el suelo.
const SLAMS := ["body-slam", "high-jump-kick", "jump-kick", "stomp", "heavy-slam", "heat-crash", "double-edge", "crabhammer", "dragon-hammer", "wood-hammer", "ice-hammer",
		# Reasignados (2026-10-10).
		"body-press", "flying-press", "strength", "gigaton-hammer", "supercell-slam", "aqua-tail", "liquidation", "grav-apple", "drum-beating"
]
## Explosiones: estallido en anillo con humo (alcanza a todos cerca).
const EXPLOSIONS := ["explosion", "self-destruct", "misty-explosion", "lava-plume", "sludge-wave", "mind-blown", "steam-eruption",
		# Reasignados (2026-10-10).
		"final-gambit", "metal-burst", "shell-trap", "mirror-coat"
]
## Sonido: ondas en arco y notas del atacante al rival.
const SOUNDS := ["hyper-voice", "boomburst", "bug-buzz", "round", "uproar", "snarl", "echoed-voice", "overdrive", "clanging-scales", "relic-song",
		# Reasignados (2026-10-10).
		"snore", "alluring-voice", "torch-song", "night-daze", "revelation-dance"
]
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
	# El resto de los ataques de daño: animación según su tipo (decisión de Fernando, 2026-10-10).
	if Moves.get_move(id).get("class", "status") != "status":
		return "typed"
	return ""


## Forma de la animación según el tipo (ataques sin familia propia).
const TYPE_SHAPES := {
	PokemonTypes.Type.NORMAL: "star", PokemonTypes.Type.FIGHTING: "fist", PokemonTypes.Type.FLYING: "feather",
	PokemonTypes.Type.POISON: "orb", PokemonTypes.Type.GROUND: "rock", PokemonTypes.Type.ROCK: "rock",
	PokemonTypes.Type.BUG: "needle", PokemonTypes.Type.GHOST: "orb", PokemonTypes.Type.STEEL: "star",
	PokemonTypes.Type.FIRE: "flame", PokemonTypes.Type.WATER: "drop", PokemonTypes.Type.GRASS: "leaf",
	PokemonTypes.Type.ELECTRIC: "star", PokemonTypes.Type.PSYCHIC: "ring", PokemonTypes.Type.ICE: "icicle",
	PokemonTypes.Type.DRAGON: "orb", PokemonTypes.Type.DARK: "orb", PokemonTypes.Type.FAIRY: "star",
}
## Forma del golpe físico según el tipo.
const TYPE_MELEE := {
	PokemonTypes.Type.STEEL: "slash", PokemonTypes.Type.DARK: "slash", PokemonTypes.Type.GRASS: "slash",
	PokemonTypes.Type.DRAGON: "claw", PokemonTypes.Type.BUG: "cross", PokemonTypes.Type.FLYING: "slash",
}


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
