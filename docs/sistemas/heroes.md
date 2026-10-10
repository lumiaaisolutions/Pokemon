# Héroes no elegidos (hecho, 2026-10-10)

[← Índice](../README.md) · Código: `world/npc/heroes.gd`, IA lista en `world/battle/battle_manager.gd` (`_smart_opponent`, `_pick_smart_next`, `_trainer_mega`). Prueba: `tests/test_battle.tscn` (sección 11).

Acordado con Fernando: el personaje que eliges es tuyo; los otros 9 protagonistas existen como **entrenadores únicos, fuertes y competitivos**.

## Dónde están
- Cada día cada héroe está en un **pueblo o lugar distinto** (fijo por semilla y día), de **8:00 a 20:00**, paseando en un radio de 6 m. Nombre en dorado con ★.
- El **Rotom** publica cada día **2 rumores** ("vieron a Red cerca de…") y esos héroes se marcan en el **mapa** con una estrella.

## Equipos (icónicos, con una mega)
| Héroe | Equipo | Mega |
|---|---|---|
| Red | Pikachu, Charizard, Venusaur, Blastoise, Snorlax, Lapras | Charizard X |
| Leaf | Venusaur, Clefable, Espeon, Ninetales, Pidgeot, Lapras | Venusaur |
| Ethan | Typhlosion, Ampharos, Togekiss, Heracross, Quagsire, Ursaring | Ampharos |
| Lyra | Meganium, Azumarill, Steelix, Wigglytuff, Furret, Xatu | Steelix |
| Brendan | Sceptile, Swellow, Breloom, Manectric, Aggron, Salamence | Sceptile |
| May | Blaziken, Beautifly, Delcatty, Altaria, Wailord, Glalie | Blaziken |
| Lucas | Infernape, Staraptor, Luxray, Garchomp, Roserade, Bronzong | Garchomp |
| Dawn | Empoleon, Lopunny, Togekiss, Pachirisu, Mamoswine, Froslass | Lopunny |
| Calem | Greninja, Talonflame, Aegislash, Gyarados, Hawlucha, Goodra | Gyarados |
| Serena | Delphox, Sylveon, Pangoro, Absol, Florges, Tyrantrum | Absol |

## Crecen contigo
- **Tamaño del equipo:** 2 + medallas / 2 (redondeado arriba), de 2 a 6.
- **Formas:** con 0–1 medallas usan la forma básica de cada línea; con 2–4, la media; con 5 o más, la final.
- **Mega** desde las 6 medallas (megaevolucionan al sacar a ese Pokémon).

## IA lista
- Eligen al **siguiente Pokémon con ventaja de tipo** contra el tuyo.
- **2 Hiperpociones** por combate (curan 50 % cuando su Pokémon baja de 30 %).
- **Esquivan** de lado cuando tu Pokémon prepara un ataque (espera de 2.5 s).

## Reto
- Al hablarles: diálogo con su retrato y **Retar / Adiós**. Premio: $1,500 + $600 por medalla y un objeto (Caramelo Raro, Trozo Estrella, Ultra Ball o Pepita). **Revancha al día siguiente.**
