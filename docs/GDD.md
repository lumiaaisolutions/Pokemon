# GDD — Pokémon Mundo Abierto

[← Índice](README.md)

## Forma de trabajo
- Desarrollador senior en Godot 4 (GDScript tipado), proyecto **personal y privado** para macOS (Apple Silicon).
- **Una fase a la vez.** Antes de cada fase, plan breve en [ESTADO.md](ESTADO.md) y confirmación de Fernando.
- Al cerrar cada fase: todas las pruebas en headless pasan (`tools/run_tests.sh`), se actualizan [ESTADO.md](ESTADO.md), el `.md` del sistema afectado y [historial.md](historial.md), y se hace commit con el prefijo `Fase N:`.
- Usar la última versión 4.x estable y verificar las APIs en esa versión; si una decisión no está documentada, preguntar a Fernando (no asumir).
- Documentación modular: un `.md` por tema ([índice](README.md)).
- Rendimiento objetivo: 60 FPS estables a 1080p en M1. Datos en Resources (`.tres`), nada hardcodeado.

## Visión
Juego de exploración y colección en un mundo abierto HD-2D (pixel art de B2W2) en tercera persona. Los Pokémon viven por su cuenta: pasean, forman manadas, pelean entre ellos, te persiguen o huyen según su naturaleza, te emboscan desde los árboles y se esconden. Se pueden capturar en el mundo apuntando y lanzando la Pokéball, o en un combate en tiempo real en el mismo lugar del encuentro.

**Ciclo principal** (debe funcionar completo antes de expandir contenido):
explorar → ver un Pokémon → encuentro → combate en tiempo real con tu Pokémon → debilitarlo → captura → se une al equipo y te sigue.

## Fases y criterio de "hecho"
| Fase | Entregable | Hecho cuando… |
|---|---|---|
| 0 | Proyecto base | Estructura, autoloads, Input Map dual, importación pixel art, repo ✅ |
| 1 | Jugador y primer bioma | Nate camina y corre (teclado y mando), cámara libre, Pradera HD-2D con colisiones ✅ |
| 2 | Hierba y Pokémon visibles | Hierba alta a 60 FPS, salvajes con IA, compañero que te sigue ✅ |
| 2.5 | Mundo de 3 biomas | Biomas con río, lago, pantano y costa; 1,025 especies por hábitat; shiny; tamaños; persecución con stamina ✅ |
| 2.8 | Mundo vivo | Aparición por zonas, manadas, escondite, legendarios en santuarios, vida del jugador, peleas, emboscadas, captura en el mundo y mapa |
| 2.6 | Asentamientos y lugares icónicos | Ver [catálogo](catalogo_mundo.md) |
| 2.7 | Vida del mundo | NPC con rutinas, día/noche y clima |
| 3 | Combate en tiempo real | Arena en el lugar del encuentro, ataques físicos y especiales, esquiva, tipos; ganar y huir funcionan ([combate](sistemas/combate.md)) |
| 4 | Captura en combate | Primera persona con física, esquiva, probabilidad, éxito y fallo |
| 5 | Equipo, inventario, UI y guardado | Menú de equipo, cambio de compañero, inventario, Pokédex con hábitats, inicial con huevos, guardar y cargar |
| 5.5 | Misiones y progresión | Piedra Llave, megapiedras por misiones, desbloqueos y evolución ([progresión](sistemas/progresion.md)) |
| 5.6 | Entrenadores NPC | Equipo por zona, campo de visión y combate, rutas propias, estado de derrotado guardado |
| 5.7 | Interiores | Ver [catálogo](catalogo_mundo.md) |
| 5.8 | Actividades | Ver [catálogo](catalogo_mundo.md) |
| 6 | Contenido final | Jefe del bioma 3 y balance del roster |
| 7 | Pulido y entrega | Audio, partículas, transiciones, pantalla de carga, export macOS (arm64) firmado ad-hoc para uso personal |

**Regla:** al terminar la Fase 4 el ciclo principal debe poder jugarse de punta a punta. Si algo posterior lo pone en riesgo, se recorta contenido, no el ciclo.

*La versión original de este documento (el "prompt maestro") está en el historial de git.*
