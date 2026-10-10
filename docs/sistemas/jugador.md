# Jugador (Nate) y cámara

[← Índice](../README.md) · Código: `world/player/`, `world/camera/`, `world/capture/throw_aim.gd`, `ui/hud.*`

## Controles
| Acción | Teclado y mouse | Mando |
|---|---|---|
| Moverse | WASD | Stick izquierdo (velocidad proporcional) |
| Correr (gasta stamina) | Shift | L3 |
| Saltar (en combate: esquivar) | Espacio | B / Círculo |
| Bucear | Ctrl | LB |
| Cámara | Mouse (clic captura el cursor, Esc lo libera) o flechas | Stick derecho |
| Zoom | Rueda | Cruceta ← → |
| Apuntar / lanzar Pokéball | Clic derecho / clic izquierdo | LT / RT |
| Mapa | M | Select |
| Interactuar | E | A / Cruz |

`project.godot` se regenera con `tools/setup_project.gd`.

## Movimiento
- Caminar a 4.5 m/s, correr a 8 m/s, relativos a la cámara y con velocidad constante en pendientes.
- **Stamina:** correr 5 s la agota y hay que recuperar el 25 % para volver a correr (barra en el HUD solo si no está llena).
- **Salto** de unos 1.4 m.
- Sprite: hoja overworld de Nate (caminar y correr en 4 direcciones). El lado visible depende de la cámara (`DirectionalSprite`).

## Vida (estilo Minecraft)
- 20 de vida = 10 corazones en el HUD.
- **Caídas:** de más de 4 m quitan 1 por metro extra.
- **Agua:** nada en la superficie (más lento, gasta stamina; sin stamina se hunde) y bucea. Tiene 15 s de aire (10 burbujas); sin aire pierde 1 por segundo. Con la cámara bajo el agua, tinte azul.
- **Ataques de salvajes:** de 1 a 6 según su ataque (ver [peleas](peleas.md)).
- **Desmayo** a 0: queda en el suelo con estrellitas y la vida se llena en 2 min mientras su compañero lo protege. Si el compañero cae, o si Nate se desmaya en el agua, es **desmayo definitivo**: pantalla negra con "¡Nate se desmayó!", pierde 10 % del dinero y reaparece en `GameState.respawn_point` (el inicio hasta que existan los Centros Pokémon, capa 2.6).

## Cámara
- Tercera persona: órbita libre de 360°, pitch de −20° a 80°, zoom de 4 a 11 m y seguimiento suave.
- El brazo de la cámara solo choca con el terreno (no con árboles ni actores).
- Al apuntar: sobre el hombro derecho, a 2.8 m y casi horizontal.
