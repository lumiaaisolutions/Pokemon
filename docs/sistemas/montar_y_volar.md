# Bicicleta, montura y vuelo

[← Índice](../README.md) · Estado: **hecho** (2026-10-10). Código: `world/player/player.gd` (Ride), `world/main.gd` (`toggle_ride`), `PokemonActor._process_ridden`.

Un solo botón: **Montar** (V / cruceta ←; en el mando el zoom quedó en cruceta →, que da la vuelta al llegar al más cercano).

| Modo | Cómo | Detalles |
|---|---|---|
| Bicicleta | La regala el profesor (o desde la Mochila: "Montar / bajar") | ×1.5 de correr; ×2 en caminos y pueblos; sin stamina; en el agua te bajas solo |
| Montura | Compañero fuera, de 1 m o más (no solo acuático) y **Licencia de Montura** | Velocidad según su Velocidad base (8.5–14 m/s, +25 % corriendo). Roca/Tierra y trepadores **suben paredes** de hasta 68°. Al entrar al agua te bajas (los de tipo Agua pasan a surf) |
| Vuelo | Montado en un volador grande (Volador o dragón grande) y **Licencia de Vuelo**; saltar despega | Libre: se mueve con la cámara, saltar sube, bucear baja, correr acelera (15–24 m/s); techo a 260 m; al tocar el suelo bajando aterriza montado. En lo alto no te puedes bajar |

- **Licencias** (se las pides al profesor): Montura con 1 medalla o 2 actividades del Rotom cumplidas; Vuelo con 3 medallas o 5 actividades.
- Se ve al jugador sentado sobre su Pokémon (piernas recortadas) o sobre una bicicleta pixel art generada.
- Al guardar al compañero, cambiarlo o desmayarte, te bajas. Las ruinas flotantes solo se alcanzan volando.
