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
