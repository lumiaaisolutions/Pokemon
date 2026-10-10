# Profesor, asistente y rival (hecho, 2026-10-10)

[← Índice](../README.md) · Código: `world/npc/professor.gd`, `world/npc/rival.gd`, lab en `world/region/interiors.gd`. Prueba: `tests/test_battle.tscn` (secciones 12 y 13). Héroes: ver [héroes](heroes.md).

## Profesor
- Nombre al azar por partida (Oak, Elm, Birch, Rowan, Encina, Sycamore, Kukui, Magnolia, Sada, Turo). **Sprite de su propio juego** (pedido de Fernando, lote 3): **Oak y Rowan** de Platino ("NPCs", sección Other), **Elm** de HGSS ("Trainers (Overworld)", mismo orden de cuadros que Red). **Kukui, Sada y Turo** de Zender1752 (fans, estilo DS; lote 4). **Birch** usa el científico (decidido por Fernando: su único sprite es de GBA); **Encina, Sycamore y Magnolia** usan la científica o el científico (Encina no se encontró en BW2 y los otros dos solo tienen versiones de fans en estilo GBA).
- **Retrato oficial** en el diálogo para todos (`art/portraits/`, del paquete de Showdown).
- **Laboratorio de 8:00 a 19:00**; de noche, en su casa (no se ve).
- **1 o 2 días por semana sale de viaje** (fijos por semilla) a un lugar de investigación: ruinas, cueva, gruta, árbol milenario, ruinas flotantes, ruinas del laboratorio, santuario, barco hundido o faro. Allá se le ve paseando con su nombre; al hablarle da un **premio especial** una vez por viaje (5 Ultra Balls, 2 Caramelos Raros, 2 Trozos Estrella, Huevo Suerte o 3 Fragmentos).
- En el **mapa** se marca dónde está mientras viaja.

## Asistente (siempre en el laboratorio, sprite del doctor de BW2)
- Te dice **dónde está el profesor** (de viaje, en su casa o en el laboratorio) y, si viaja, **lo marca como destino** en el mapa.
- **Recibe tus registros** y entrega los **premios de investigación** (los mismos del profesor).

## Rival
- De Hugh, Cheren y Bianca solo **Hugh** está en la hoja de BW2 (Fernando confirmó que los otros dos no aparecen), así que el rival es Hugh. Partidas viejas con otro rival pasan a Hugh.
- **Te busca tras cada medalla** (aparece frente a ti con "¡!" y se acerca) **y cada 2 o 3 días** en el mundo (de 9:00 a 19:00).
- Equipo de B2W2: el inicial que le gana al tuyo (Emboar, Samurott o Serperior) + Unfezant, Bouffalant, Simipour, Flareon y Eelektross. **Crece con tus medallas** como los héroes; **IA lista** con 1 poción. Premio: $1,200 + $500 por medalla y un objeto.

## Interiores
- Los figurantes de las casas, el tutor y los líderes usan aspectos de BW2 (`NpcLooks`), ya no los héroes. Los líderes de gimnasio por tipo y generación llegan con las [regiones](regiones.md).

## Catálogo de personajes
`~/Desktop/Pokemon_personajes_BW2.png`: todos los personajes de la hoja numerados (A = caminan, B = Torneo Mundial), para identificar líderes con Fernando antes de las regiones.
