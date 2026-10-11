# Decisiones tomadas sin preguntar (para revisar)

[← Índice](README.md) · Fernando autorizó (2026-10-10, noche) que, mientras duerme, ante una duda de diseño nueva se elija la opción recomendada y se anote aquí con sus alternativas. Revísalas: cualquiera se puede cambiar.

| Fecha | Tema | Elegido | Alternativas | Dónde |
|---|---|---|---|---|
| 2026-10-10 | Radio de la pared invisible de la ceremonia del inicial | 16 m alrededor de la plaza (holgado para moverse entre los 4 candidatos sin dejar salir) | Un radio menor (más estricto) o atado al radio real del pueblo (60 m, demasiado grande) | `world/starter/starter_ceremony.gd` (`PLAZA_RADIUS`) |
| 2026-10-10 | Cuántas Poké Balls regala el profesor al elegir compañero | 5 | 1, 3 o depender de la mochila inicial | `world/starter/starter_ceremony.gd` (`GIFT_BALLS`) |
| 2026-10-10 | Música de la cinemática del inicio ("introducción de BW2") | Clave `bw2_title` (tema de título de BW2, ya referenciado en la selección de personaje); no existen archivos de música en este equipo todavía, así que no suena hasta que se descarguen | Pedir el archivo de la cinemática real de N (no catalogada) o dejarlo en silencio | `world/starter/intro_cinematic.gd` |
| 2026-10-10 | Cómo buscar los 4 lugares (pradera/bosque/costa/montaña) del viaje del profesor | Espiral desde la plaza inicial consultando el bioma exacto (`WorldBuilder.region_biome_at`), hasta 1800 m | Puntos fijos por compás (N/S/E/O) o requerir que estén dentro de un radio fijo menor | `world/starter/intro_cinematic.gd` (`_find_point`) |
