# Jugador (Nate) y cámara

[← Índice](../README.md) · Código: `world/player/`, `world/camera/`, `world/capture/throw_aim.gd`, `ui/hud.*`

## Controles
| Acción | Teclado y mouse | Mando |
|---|---|---|
| Moverse | WASD | Stick izquierdo (velocidad proporcional) |
| Correr (gasta stamina) | Shift | L3 |
| Saltar (en combate: esquivar) | Espacio | B / Círculo |
| En el agua: mantener para flotar o subir / bucear más rápido | Espacio / Ctrl | ○ / L1 |
| Guardar o sacar al compañero | Q | △ |
| Cámara | Mouse (clic captura el cursor, Esc lo libera) o flechas | Stick derecho |
| Zoom | Rueda | Cruceta ← → |
| Apuntar (toque: fija la mira; mantener: mientras se sostiene) / lanzar Pokéball | Clic derecho / clic izquierdo | L2 / R2 |
| Ayuda (todos los controles) | H | Touchpad |
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
- **Agua:** se hunde poco a poco solo (0.8 m/s); **mantener Espacio / ○** lo mantiene a flote con la cabeza fuera o lo sube, y Ctrl / L1 lo baja más rápido. Nadar gasta stamina solo al moverse y agotado nada más lento. Tiene 15 s de aire: las burbujas (con la etiqueta "Aire") se ven siempre que está en el agua; sin aire pierde 1 por segundo. Con la cámara bajo el agua, tinte azul.
  - **Nado generado** (los personajes no traen sprites de nado): en la superficie solo se ve de la cintura para arriba (el shader no dibuja lo que queda bajo el agua), con brazadas lentas, balanceo y salpicaduras; buceando se inclina como nadando de pecho, con burbujas.
  - **Surf:** si el compañero es de tipo Agua, el jugador va sentado sobre él (más rápido, sin gastar stamina, no se hunde). Si no lo es, el compañero vuelve a su Pokéball al entrar al agua y sale solo al volver a tierra.
  - **Mar abierto:** a 30 m del borde una corriente lo regresa ("La corriente es muy fuerte...").
- **Daño:** el sprite se pinta de rojo y parpadea al recibir cualquier daño (ataques, caídas, ahogarse).
- **Descanso:** tras 10 s sin daño (y con aire completo) recupera 0.25 de vida por segundo. Comida, camas, el compañero y lugares curativos llegarán con la mochila y el día y la noche ([plan](historia_y_mundo_aleatorio.md)).
- **Stamina:** barra verde con un rayo amarillo (roja si está agotado); es distinta de la del aire.
- **Ataques de salvajes:** de 1 a 6 según su ataque (ver [peleas](peleas.md)).
- **Desmayo** a 0: Nate cae de espaldas al suelo (sprite plano con rebote y polvo), respira, tiene estrellitas sobre la cabeza y suelta destellos de curación; la vida se llena en 2 min. El HUD muestra el panel "¡Nate está desmayado!" con barra de recuperación, porcentaje y segundos, los corazones laten y la pantalla tiene un tinte rojo suave. Mientras tanto **controlas a tu compañero** (la cámara lo sigue, a máximo 10 m de Nate): golpe físico (embestida), ataque especial de su tipo (al salvaje más cercano o al frente) y esquivar (impulso invulnerable). Al llenarse se levanta con un destello y aviso "¡Nate se recuperó!". Si el compañero estaba guardado, sale solo.
- **Compañero debilitado** (en cualquier momento): aviso "¡X se debilitó!" y luego **desmayo definitivo**. También si Nate se desmaya en el agua. Pantalla negra: "Corriste al Centro Pokémon... Perdiste $N", pierde 10 % del dinero y reaparece curado con su compañero en `GameState.respawn_point` (el inicio hasta que existan los Centros Pokémon, capa 2.6).

## Cámara
- Tercera persona: órbita libre de 360°, pitch de −20° a 70°, zoom de 4 a 11 m y seguimiento suave. Más arriba de 70° los sprites se verían de canto; para ver desde arriba está el mapa.
- **Sprites que se inclinan:** todos los sprites (jugador, Pokémon, árboles, rocas, decoración) usan `world/effects/sprite_billboard.gdshader`: de pie mirando a la cámara y, cuando la cámara mira desde arriba (más de 25°), se inclinan hacia atrás desde su base para verse completos, como en los juegos HD-2D. La semitransparencia (Pokémon que tapan la vista) se dibuja con tramado.
- El brazo de la cámara solo choca con el terreno (no con árboles ni actores).
- Al apuntar: sobre el hombro derecho, a 2.8 m; la inclinación es **libre** (−50° a 45°) con el mouse o el stick, así la mira sube para lanzar lejos o hacia arriba. La Pokéball sale hacia donde mira la cámara.
- Mientras Nate está desmayado, la cámara sigue al compañero.
- Pokémon grandes que tapan a Nate se vuelven semitransparentes; la barra de vida de un salvaje se oculta si está a menos de 4.5 m de la cámara.

## Guía de botones
- **Leyenda** abajo a la derecha con íconos (`ui/input_glyph.gd`): símbolos de PlayStation dibujados en pixel art (✕ ○ □ △ con sus colores), teclas como teclado y el mouse con el botón resaltado. Cambia según el contexto: explorar, apuntar, nadar, bucear o surfear.
- **Tarjetas de tutorial** arriba a la izquierda la primera vez que algo es posible (moverse, apuntar y lanzar, nadar y surfear), una vez por partida (`GameState.tips_seen`).
- **Ayuda** (H / Touchpad, `ui/help_overlay.gd`): todos los controles con el ícono del teclado de Mac y el del control de PlayStation lado a lado; pausa el juego.

## Ayudas de botones (detalle)
- `InputHints` (autoload) detecta el último dispositivo y nombra cada acción ("Q" o "△"). El HUD muestra ayudas según el contexto (explorar, apuntar, nadar, bucear, desmayado) y la tarjeta del compañero (vida, si está fuera, guardado o debilitado).
