# Jugador (Nate) y cámara

[← Índice](../README.md) · Código: `world/player/`, `world/camera/`, `world/capture/throw_aim.gd`, `ui/hud.*`

## Controles
| Acción | Teclado y mouse | Mando |
|---|---|---|
| Moverse | WASD | Stick izquierdo (velocidad proporcional) |
| Correr (gasta stamina) | Shift | L3 |
| Saltar (en combate: esquivar) | Espacio | B / Círculo |
| Bucear (mantener) / subir | Ctrl / Espacio o soltar Ctrl | L1 / Círculo |
| Guardar o sacar al compañero | Q | △ |
| Cámara | Mouse (clic captura el cursor, Esc lo libera) o flechas | Stick derecho |
| Zoom | Rueda | Cruceta ← → |
| Apuntar (mantener) / lanzar Pokéball | Clic derecho / clic izquierdo | L2 / R2 |
| Con Nate desmayado: golpe / ataque especial / esquivar (controlas al compañero) | 1 o clic izq. / 2 o clic der. / Espacio | □ / △ / ○ |
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
- **Agua:** flota en la superficie con la cabeza fuera (balanceo, salpicaduras al moverse); nadar gasta stamina solo al moverse y agotado nada más lento, pero no se hunde. Mantener bucear lo baja hasta el fondo (burbujas); al soltar o con saltar sube. Tiene 15 s de aire: las burbujas (con la etiqueta "Aire") se ven siempre que está en el agua; sin aire pierde 1 por segundo. Con la cámara bajo el agua, tinte azul.
- **Stamina:** barra verde con un rayo amarillo (roja si está agotado); es distinta de la del aire.
- **Ataques de salvajes:** de 1 a 6 según su ataque (ver [peleas](peleas.md)).
- **Desmayo** a 0: Nate cae de espaldas al suelo (sprite plano con rebote y polvo), respira, tiene estrellitas sobre la cabeza y suelta destellos de curación; la vida se llena en 2 min. El HUD muestra el panel "¡Nate está desmayado!" con barra de recuperación, porcentaje y segundos, los corazones laten y la pantalla tiene un tinte rojo suave. Mientras tanto **controlas a tu compañero** (la cámara lo sigue, a máximo 10 m de Nate): golpe físico (embestida), ataque especial de su tipo (al salvaje más cercano o al frente) y esquivar (impulso invulnerable). Al llenarse se levanta con un destello y aviso "¡Nate se recuperó!". Si el compañero estaba guardado, sale solo.
- **Compañero debilitado** (en cualquier momento): aviso "¡X se debilitó!" y luego **desmayo definitivo**. También si Nate se desmaya en el agua. Pantalla negra: "Corriste al Centro Pokémon... Perdiste $N", pierde 10 % del dinero y reaparece curado con su compañero en `GameState.respawn_point` (el inicio hasta que existan los Centros Pokémon, capa 2.6).

## Cámara
- Tercera persona: órbita libre de 360°, pitch de −20° a 80°, zoom de 4 a 11 m y seguimiento suave.
- El brazo de la cámara solo choca con el terreno (no con árboles ni actores).
- Al apuntar: sobre el hombro derecho, a 2.8 m; la inclinación es **libre** (−50° a 45°) con el mouse o el stick, así la mira sube para lanzar lejos o hacia arriba. La Pokéball sale hacia donde mira la cámara.
- Mientras Nate está desmayado, la cámara sigue al compañero.
- Pokémon grandes que tapan a Nate se vuelven semitransparentes; la barra de vida de un salvaje se oculta si está a menos de 4.5 m de la cámara.

## Ayudas de botones
- `InputHints` (autoload) detecta el último dispositivo y nombra cada acción ("Q" o "△"). El HUD muestra ayudas según el contexto (explorar, apuntar, nadar, bucear, desmayado) y la tarjeta del compañero (vida, si está fuera, guardado o debilitado).
