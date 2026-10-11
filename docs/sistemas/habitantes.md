# Habitantes con rutina (Fase 2.7)

[← Índice](../README.md) · Estado: **hecho** (2026-10-10). Código: `world/npc/town_npcs.gd`.

- Cada asentamiento tiene habitantes (ciudad 9, pueblo 6, aldea 4, cabañas 2), siempre los mismos para la misma semilla: nombre, oficio (vecino, vendedor, enfermera, investigador, entrenador, coordinador, niño, abuela), casa y trabajo.
- Sprites de los 10 protagonistas con tintes de ropa distintos y su nombre encima; caminan con el sprite de 4 direcciones y te miran al acercarte.
- **Rutina por hora:** se levantan entre 7:00 y 9:00 y van a la plaza; de 9:00 a 18:00 trabajan (puerta de su edificio) o pasean; de 18:00 a la hora de dormir (20:00–22:30) se juntan en la plaza; de noche están en casa (no se ven). Con tormenta, ventisca o arena se van a casa.
- Caminan siempre pasando por el centro de la plaza (las puertas miran a ella), así no atraviesan edificios.
- Se crean al acercarte a 260 m del pueblo y se liberan a 320 m.
- **Hablar** (E): saludo según la hora, algo de su oficio y un comentario del clima.
- **Su Pokémon:** el 45 % tiene un Pokémon pequeño (de los básicos) que lo sigue.
- **Viajeros:** hasta 2 caminan por los caminos cerca del jugador (fuera de los pueblos), con su Pokémon; de noche (21:00–6:00) **acampan** con carpa y fogata donde estén. Al hablarles cuentan de dónde vienen y a veces regalan algo.
- **Horarios:** la Tienda abre de 8:00 a 21:00; el Gimnasio y la Sala de Concursos de 7:00 a 22:00; el Centro Pokémon siempre.


## Cambios del 2026-10-10 (prueba de Fernando)
- **Aspecto:** clases de BW2 según su oficio (`core/npc_looks.gd`, 39 hojas en `art/npcs/` generadas con `tools/build_npc_sheets.py` desde "Overworld Entities"). Ya no usan los sprites de los héroes ni tintes. El nombre sale del género del aspecto.
- **Menos y con oficio:** 6 en ciudad, 4 en pueblo, 3 en aldea y 1 en cabañas. Cada uno tiene **su lugar** en la plaza (repartidos en círculo) y pasea según su oficio (`WANDER`: la abuela se queda quieta, los niños pasean más). **Espacio personal** de 1.4 m: no se amontonan.
- **Conversación:** se detienen y te miran; caja de diálogo con su retrato; si llevan Pokémon y **hoy tienen ganas** (por oficio: entrenador 80 %, viajero 40 %, vecino 30 %, vendedor/abuela/niño 10 %, fijo por día), ofrecen **Retar** (premio y revancha como los entrenadores de camino). Los regalos de los viajeros se entregan al cerrar el diálogo, con fanfarria.
- **Retos al verte:** viajeros (fuera del pueblo) y peleoneros del pueblo con ganas: cono de 10 m y 38°, "¡!", se acercan y empieza el combate.
- **Nadan:** en agua profunda se hunden hasta medio cuerpo, con ondas.
- **Campamentos** (`world/npc/camp.gd`): carpa y fogata en pixel art, solo fuera de pueblos; al anochecer el viajero la arma (se agacha, la carpa se levanta, se enciende el fuego) y al amanecer la recoge (apaga con humo, pliega la carpa) y sigue.

## Burbujas (contexto y charlas, 2026-10-10)
Sistema reutilizable en `world/npc/speech_bubbles.gd` (`SpeechBubbles.say(node, text, seconds, key)`): globo claro con borde (estilo de `ui/kit/ui_kit.gd`) y texto con contorno, siempre mirando a la cámara, encima del nombre del NPC; se desvanece solo. Como mucho **3 burbujas a la vez** en toda la pantalla y **enfriamiento de 3 s por persona** para no saturar; no aparecen mientras ese NPC está en diálogo o en combate. Frases en español neutro, ≤ 40 caracteres.
- **Charla entre vecinos** (`TownNPCs._update_chats`, `_try_start_chat`): cada tanto (5–9 s), si dos vecinos libres están juntos en la plaza y cerca de ti, cambian 2–3 frases alternadas (clima, Pokémon, el gimnasio, la hora, chismes del pueblo; ver `TownNPCs.CHATS`).
- **Por hora o clima** (`TownNPCs._try_solo_comment`): un vecino cercano comenta la lluvia, el frío, la arena, que ya es de noche o que hace calor en verano.
- **Órdenes al pelear** (`BattleManager._on_trainer_move`, `_trainer_says`): mientras un entrenador, viajero, héroe, líder o el rival pelea, si tenemos su nodo en el mundo (los que ya tenían uno: `heroes.gd`, `gym_leaders.gd` en combate amistoso, `rival.gd`, `route_trainers.gd`, `town_npcs.gd`), da la orden con el **nombre real del movimiento** que usa su Pokémon ("¡Usa Placaje!"), "¡Esquiva!" al mandarlo a esquivar y "¡Aguanta!" al curarlo. Se conecta a la señal `PokemonActor.move_used` (mínima, no toca la IA de combate). Los combates de gimnasio y Liga (interiores, sin nodo de persona en el mundo) no muestran burbuja.
- **Reacciones a sucesos cercanos** (`TownNPCs.react(pos, lines)`): si hay alguien visible cerca de pos y de ti, comenta al azar. Enganchado en elegir inicial y terminar la ceremonia (`world/starter/starter_ceremony.gd`), hordas y shiny (`world/actors/wild_spawner.gd`) y el paso de una migración (`world/events/migrations.gd`). Los brotes no comentan: siempre aparecen lejos de los pueblos, donde no hay vecinos cerca (ya avisa el Rotom).
