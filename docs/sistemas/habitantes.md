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
