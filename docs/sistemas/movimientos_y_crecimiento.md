# Movimientos y crecimiento sin niveles (hecho)

[← Índice](../README.md) · Decidido con Fernando el 2026-10-09; hecho el 2026-10-10. Código: `core/moves.gd`, `core/move_input.gd`, `world/actors/pokemon_actor.gd` (sección Movimientos), `ui/menu/team_tab.gd`. Datos: `tools/build_moves.py` → `creatures/data/moves.json` (744 movimientos con nombre en español) y `learnsets.json` (lista oficial de las 1,025 especies: por nivel en orden, más MT y tutor, del juego más reciente que tenga cada lista).

## Movimientos
- Cada Pokémon lleva **4 movimientos** en cualquier mezcla de físicos, especiales y de estado. Empieza con los primeros de su lista por nivel (al menos uno de daño).
- **Desbloqueo** sin niveles: cada 15 usos de movimientos se desbloquea el siguiente de su lista, y la investigación de su especie en niveles 3, 6 y 9 desbloquea uno más. Se equipan en el menú (Equipo: toca un espacio y luego el movimiento). Faltan las MT halladas en el mundo y los tutores (llegarán con los pueblos).
- **Sin PP:** cada movimiento tiene su espera según su potencia (0.8 a 3.6 s; los de estado 4 s).
- **Dominio:** 3 rangos por usos (0, 20 y 60): potencia ×1 / ×1.15 / ×1.3 y espera ×1 / ×0.85 / ×0.7. Se avisa al subir.
- **Estilos:** al usarlo, mantener correr = **Fuerte** (×1.35 de daño, ×1.6 de espera); mantener bucear = **Ágil** (×0.75 de daño, ×0.55 de espera).
- **Efectos:** físicos = embestida cuerpo a cuerpo; especiales = proyectil del color de su tipo; curación propia; **curan al entrenador** (Deseo, Aromaterapia, Pulso Cura, Rocío Vital y otros: "tu Pokémon te cura"); mejoras (+30 % de daño 12 s); aturdir (parálisis, sueño, congelación o confusión: el objetivo no actúa 2.5 s); drenaje (recupera parte del daño).
- **Botones:** teclas 1-4; en el mando, mantener R1 y pulsar □ △ ○ ✕. Explorando, **ordenan** al compañero usar ese movimiento contra el salvaje más cercano (o curarte); con el jugador desmayado, lo **controlas** directamente.
- Los salvajes también usan movimientos de su lista (más avanzados según su etapa) y eligen por distancia, ventaja de tipo y su vida. El nombre del movimiento flota sobre quien lo usa.

## Crecimiento
- **Estadísticas equilibradas:** `70 + (base − 70) × 0.5` más los Puntos de Entrenamiento. Un Pichu no queda a la par de Mewtwo, pero la diferencia baja de unas 3 veces a unas 1.6 veces.
- **Puntos de Entrenamiento:** +1 por cada salvaje que debilita tu compañero y +8 con cada Caramelo Raro; se reparten con +1 en la pestaña Equipo (máx. 31 por estadística y 127 en total).
- **Vínculo** (1 a 10): sube 1 nivel cada 20 minutos que el compañero pasa fuera contigo (×2 si se capturó con Lujo Ball). Con 5 o más aguanta con 1 de vida un golpe fatal una vez por pelea; con 8 o más tiene 10 % de golpes críticos (×1.5).
- Falta el combate de la Fase 3, que usará lo mismo (movimientos, dominio, estilos y vínculo).
