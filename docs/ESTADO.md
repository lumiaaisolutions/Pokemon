# Estado del proyecto

[← Índice](README.md) · Motor: Godot 4.7.2 estable (GDScript), macOS M1.

## Fases
| Fase | Estado | Commit | Notas |
|---|---|---|---|
| 0 | Hecha | `1f40246` | Proyecto base |
| 1 | Hecha (aprobada) | `89ba4cc` | Nate animado, cámara libre, Pradera HD-2D |
| 2 | Hecha (aprobada) | `33a8792` | Hierba alta, salvajes con IA, compañero al azar |
| 2.5 | Hecha (probada por Fernando; sus comentarios dieron la 2.8) | `cadf095` | 3 biomas con agua, aparición por hábitat, shiny, persecución con stamina |
| 2.8 | Implementada, esperando revisión de Fernando | ver `git log` | Los 7 bloques (ver [historial](historial.md)); 7 pruebas en headless con 0 fallos |
| 2.6 | Pendiente | — | Asentamientos y lugares icónicos ([catálogo](catalogo_mundo.md)) |
| 2.7 | Pendiente | — | NPC con rutinas, día/noche, clima |
| 3 | Pendiente | — | Combate en tiempo real |
| 4 | Pendiente | — | Captura en combate |
| 5 | Pendiente | — | Equipo, inventario, UI, guardado, inicial con huevos |
| 5.5 | Pendiente | — | Misiones, Piedra Llave, megapiedras, desbloqueos |
| 5.6 | Pendiente | — | Entrenadores NPC |
| 5.7 | Pendiente | — | Interiores |
| 5.8 | Pendiente | — | Actividades (pesca, Surf, hordas, equipo villano, bayas) |
| 6 | Pendiente | — | Jefe y balance |
| 7 | Pendiente | — | Pulido y entrega |

## Por confirmar con Fernando
- Si el compañero cae con Nate de pie: ¿vuelve a su Pokéball y regresa a los 30 s con la mitad de la vida? (supuesto actual).
- Entrenadores NPC (5.6): recompensa y si vuelven a retar.
- Misiones y desbloqueos (5.5): qué desbloquea cada habilidad, cómo se gana y tipos de misión.
- Ideas propuestas en el [catálogo](catalogo_mundo.md) (Zona Safari, concursos, estaciones…).

## Pendientes técnicos
- El mundo tarda ~5–6.5 s en construirse (incluye la imagen del mapa): pantalla de carga u optimización.
- FPS de 55–60 en el bosque denso y la montaña (meta: 60 estable).
