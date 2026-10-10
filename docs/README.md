# Pokémon Mundo Abierto — documentación

Fan game **personal y privado** en Godot 4.7.2 para macOS (M1): mundo abierto HD-2D con gráficos de Pokémon Negro 2/Blanco 2, Pokémon que viven por su cuenta, peleas y captura en el mundo, combate en arena en tiempo real, megaevolución, evolución sin niveles y entrenadores en los caminos.

## Empezar
- Jugar: `godot --path .` (o abrir el proyecto en Godot).
- Pruebas: `tools/run_tests.sh` (unos 8 min, 11 pruebas; deben pasar todas antes de cada commit).
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
| [plan_pulido_mundo.md](plan_pulido_mundo.md) | Plan acordado tras la prueba de Fernando (bugs, NPC, mapa, interiores, biomas, interfaz, pueblos, tablero, regiones) y su avance |

### Sistemas
| Sistema | Documento |
|---|---|
| Dirección de arte y assets | [sistemas/arte.md](sistemas/arte.md) |
| Mundo fijo de 480 m (versión anterior, referencia) | [sistemas/mundo.md](sistemas/mundo.md) |
| Jugador, controles y cámara | [sistemas/jugador.md](sistemas/jugador.md) |
| Pokémon salvajes (datos, aparición, IA, compañero) | [sistemas/pokemon_salvajes.md](sistemas/pokemon_salvajes.md) |
| Legendarios | [sistemas/legendarios.md](sistemas/legendarios.md) |
| Peleas en el mundo | [sistemas/peleas.md](sistemas/peleas.md) |
| Captura | [sistemas/captura.md](sistemas/captura.md) |
| Mapa y minimapa | [sistemas/mapa.md](sistemas/mapa.md) |
| Menú, mochila, Pokéballs, Pokédex, guardado y opciones (hecho) | [sistemas/mochila_y_pokedex.md](sistemas/mochila_y_pokedex.md) |
| Personaje, menú, mochila, Pokédex, guardado y opciones (2.9, hecho) | [sistemas/menu_y_personaje.md](sistemas/menu_y_personaje.md) |
| Historia, caminos, tiempo, mundo aleatorio, curación y agua (hecho) | [sistemas/historia_y_mundo_aleatorio.md](sistemas/historia_y_mundo_aleatorio.md) |
| Mundo grande generado: 4 × 4 km por zonas, 17 biomas, agua, lugares, navegación y mapa (hecho) | [sistemas/mundo_grande.md](sistemas/mundo_grande.md) |
| Pueblos, lugares especiales, interiores, tienda, gimnasios, retos y MT (hecho) | [sistemas/pueblos_e_interiores.md](sistemas/pueblos_e_interiores.md) |
| Clima por bioma, estaciones y eventos del mundo (hecho) | [sistemas/clima_y_eventos.md](sistemas/clima_y_eventos.md) |
| Bicicleta, montura y vuelo (hecho) | [sistemas/montar_y_volar.md](sistemas/montar_y_volar.md) |
| Habitantes con rutina, Fase 2.7 (hecho) | [sistemas/habitantes.md](sistemas/habitantes.md) |
| Movimientos y crecimiento sin niveles (hecho) | [sistemas/movimientos_y_crecimiento.md](sistemas/movimientos_y_crecimiento.md) |
| Combate en arena, captura en combate y megaevolución, Fases 3 y 4 (hecho) | [sistemas/combate.md](sistemas/combate.md) |
| Progresión: inicial, evolución sin niveles, Piedra Llave, megapiedras y fotografía, 5.5 (hecho) | [sistemas/progresion.md](sistemas/progresion.md) |
| Entrenadores en los caminos, 5.6 (hecho) | [sistemas/entrenadores.md](sistemas/entrenadores.md) |
| Interfaz: kit visual, pantalla de inicio, menú y HUD (hecho) | [sistemas/interfaz.md](sistemas/interfaz.md) |
| Música y sonido de BW/BW2 (hecho) | [sistemas/musica_y_sonido.md](sistemas/musica_y_sonido.md) |
| Edificios y decoración con modelos de B2W2 (hecho) | [sistemas/edificios_b2w2.md](sistemas/edificios_b2w2.md) |
| Héroes no elegidos: entrenadores únicos con IA lista (hecho) | [sistemas/heroes.md](sistemas/heroes.md) |
| Viaje por regiones (diseñado, por hacer) | [sistemas/regiones.md](sistemas/regiones.md) |

Regla: cada tema se documenta en su propio `.md`; al cerrar una fase se actualiza el documento del sistema afectado, [ESTADO.md](ESTADO.md) y [historial.md](historial.md).
