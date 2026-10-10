# Pokémon Mundo Abierto — documentación

Fan game **personal y privado** en Godot 4.7.2 para macOS (M1): mundo abierto HD-2D con gráficos de Pokémon Negro 2/Blanco 2, Pokémon que viven por su cuenta, peleas y captura en el mundo, combate en tiempo real (por hacer) y megaevolución.

## Empezar
- Jugar: `godot --path .` (o abrir el proyecto en Godot).
- Pruebas: `tools/run_tests.sh` (unos 4 min; deben pasar todas antes de cada commit).
- Regenerar datos y sprites: ver [herramientas.md](herramientas.md).

## Documentos
| Documento | Contenido |
|---|---|
| [GDD.md](GDD.md) | Visión, ciclo principal, reglas de trabajo y fases con su criterio de "hecho" |
| [ESTADO.md](ESTADO.md) | Tabla de estado de las fases y pendientes |
| [decisiones.md](decisiones.md) | Registro de decisiones de diseño |
| [historial.md](historial.md) | Qué se hizo en cada fase y por qué cambió |
| [catalogo_mundo.md](catalogo_mundo.md) | Todo lo planeado para el mundo, por capas |
| [herramientas.md](herramientas.md) | Scripts de `tools/` y pruebas |

### Sistemas
| Sistema | Documento |
|---|---|
| Dirección de arte y assets | [sistemas/arte.md](sistemas/arte.md) |
| Mundo (biomas, agua, vegetación, rendimiento) | [sistemas/mundo.md](sistemas/mundo.md) |
| Jugador, controles y cámara | [sistemas/jugador.md](sistemas/jugador.md) |
| Pokémon salvajes (datos, aparición, IA, compañero) | [sistemas/pokemon_salvajes.md](sistemas/pokemon_salvajes.md) |
| Legendarios | [sistemas/legendarios.md](sistemas/legendarios.md) |
| Peleas en el mundo | [sistemas/peleas.md](sistemas/peleas.md) |
| Captura | [sistemas/captura.md](sistemas/captura.md) |
| Mapa y minimapa | [sistemas/mapa.md](sistemas/mapa.md) |
| Combate y megaevolución (por hacer) | [sistemas/combate.md](sistemas/combate.md) |
| Progresión, iniciales, misiones y entrenadores (por hacer) | [sistemas/progresion.md](sistemas/progresion.md) |

Regla: cada tema se documenta en su propio `.md`; al cerrar una fase se actualiza el documento del sistema afectado, [ESTADO.md](ESTADO.md) y [historial.md](historial.md).
