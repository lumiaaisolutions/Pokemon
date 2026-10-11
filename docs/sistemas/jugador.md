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

## Campamento, comida y hambre (pedido de Fernando, 2026-10-10 · hecho)
Código: `core/game_state.gd` (hambre), `core/save_system.gd` (persistencia), `core/items.gd` y `creatures/data/items.json` (comida, Cañas, recetas de cocina), `core/item_effects.gd` (comer, armar tienda, pescar, cocinar), `world/player/player.gd` (`_update_hunger`), `ui/hud.gd`/`ui/hud.tscn` (muslitos), `world/camp/camp_manager.gd` (tiendas del jugador), `world/npc/camp.gd` (visual reutilizado, `set_lit_instant`), `ui/camp/cooking_ui.gd` (cocinar), `world/fishing/fishing_minigame.gd` (pesca), `world/region/structures.gd` (restaurante y puesto de comida), `world/region/town_identity.gd` (regalo del pescador), `ui/shop/food_stall_ui.gd`, `ui/shop/restaurant_ui.gd`, `ui/shop/shop_ui.gd` (Cañas y comida en la tienda).
- Sacar la **tienda de campaña** y **descansar hasta el día** (solo de noche): repone la vida del jugador y de sus Pokémon.
- Sacar el campamento para **cocinar comida**; la comida se **compra o se consigue en el mapa** y recupera vida.
- **Indicador de hambre** como en Minecraft: si se vacía, el jugador pierde vida con el tiempo; tiene **10 minutos** para conseguir comida (lo que dura su vida con hambre).
### Decisiones (2026-10-10)
- **Barra de hambre:** 10 muslitos a la derecha de los corazones (como Minecraft). Se vacía en **2 días del juego** (48 min de juego); correr, nadar y pelear la bajan un poco más rápido. Vacía: pierdes vida poco a poco y en **10 min** te quedas sin vida.
- **Comida, de dónde sale:**
  - **Recolectar** bayas, setas y bonguris y comerlos crudos: recupera **muy poco**.
  - **Comprar** en la Tienda Pokémon (pan, sándwiches, latas de curry, bebidas).
  - **Cocinar** en el campamento: recetas que combinan ingredientes (curry, sándwich, estofado de bayas), llenan mucho más y dan un efecto extra.
  - **Pescar con caña:** da pescado **crudo**, que hay que **cocinar en la fogata** de la tienda de campaña.
  - **Restaurantes** en las ciudades.
- **Tienda de campaña:** se arma con una tecla en un lugar plano **fuera de los pueblos**. **De noche** puedes dormir hasta las 7:00: recupera tu vida y la de tu equipo y guarda el punto de reaparición. **Dormir no recupera el hambre.** De día solo sirve para cocinar.
  - **Si no la recoges, se queda ahí:** si te alejas, debes volver por ella o conseguir otra; si tienes más de una, cada una se queda donde la dejaste.
- **Cocinar:** fogata con olla; eliges ingredientes en un menú, animación corta de remover y **tu equipo sale a comer contigo** (sube su vínculo).
- **Pesca:** con la Caña en el agua: lanzas, el corcho se hunde ("¡!") y aprietas a tiempo. Sale **pescado crudo** y a veces un **Pokémon de agua** que pelea.
- **Objetos:** empiezas con **1 tienda de campaña**; más se compran en la Tienda Pokémon ($1,500). La **Caña** te la regala un pescador del pueblo pesquero (o se compra en las ciudades).
- **Restaurantes y puestos (ambos):** un **restaurante** por ciudad (edificio de B2W2, menú de 3–4 platillos: llena mucho el hambre y da un efecto) y un **puesto de comida** en la plaza de pueblos y ciudades (más barato, **recupera menos**).
- **Uso de la tienda:** desde la **Mochila o la rueda rápida**; junto a tu tienda, **E** abre su menú: Dormir (de noche), Cocinar o Recoger.

### Hecho (detalles de la implementación)
- **Hambre:** `GameState.hunger` (0 a `HUNGER_MAX` = 10), se vacía con `drain_hunger()` (llamada cada físico desde `Player._update_hunger`, con `fast = true` al correr, nadar moviéndose o pelear) y se llena con `feed()`. Vacía del todo, `Player._update_hunger` quita `config.health_max / GameState.STARVE_SECONDS` de vida una vez por segundo. Se guarda y carga con la partida (`SaveSystem`).
- **Comida:** las bayas, setas y bonguris ya existentes ganaron un campo `feed` pequeño (0.3 a 0.6) además de su `heal_hearts` de siempre. Nuevos objetos de tienda (`bread`, `sandwich-shop`, `curry-can`, `soda`) y de cocina (`curry-dish`, `sandwich-dish`, `berry-stew`, `grilled-fish`, estos últimos solo como referencia de receta: se comen al instante al cocinarlos, no se guardan en la mochila). `raw-fish` no tiene `feed` a propósito: no se puede comer crudo.
- **Tienda de campaña:** el objeto `tent` (antes `explorer-kit`) se usa desde la Mochila (`ItemEffects.use`); `CampManager.pitch_tent()` valida el lugar (`WorldBuilder.settlement_at`, `.structures.place_at`, `._dry_land`) y crea el `Camp` visual (reutilizado de `world/npc/camp.gd`) más un punto de interacción. Las tiendas armadas se guardan en `GameState.world_flags["tents"]` y `CampManager._ready()` las reconstruye (sin animación, `Camp.set_lit_instant()`) al cargar la partida.
- **Dormir, Cocinar, Recoger:** el punto de interacción junto a la tienda abre una `DialogBox` con esas 3 opciones (y "Nada"). Dormir usa `GameState.sleep_until_morning()` solo si `GameState.is_night()`, sin tocar el hambre. Cocinar abre `CookingUI` (lista `Items.cook_recipes()`) que llama a `ItemEffects.cook()`: consume ingredientes, llena hambre, aplica el efecto extra (`boost` o `heal_hearts`) y sube `bond_xp` de todo el equipo.
- **Pesca:** `ItemEffects.use()` con un objeto que tenga el campo `rod` (`old-rod`, `good-rod`) crea un `FishingMinigame` si hay agua cerca (`WorldBuilder.water_depth_at`); espera, avisa "¡!" y hay que apretar Interactuar a tiempo. La Caña Vieja la regala, una vez por partida, un punto de interacción junto al monumento de los pueblos pesqueros (`TownIdentity._give_rod`); la Caña Buena se vende en la Tienda Pokémon.
- **Restaurante y puesto:** `Structures._food_places()` agrega ambos cerca del centro de la plaza de cada asentamiento (puesto en todos, restaurante solo en ciudades) con un punto de interacción que abre `FoodStallUI` o `RestaurantUI`; ahí se come al instante (no ocupa espacio en la mochila).
- **Simplificaciones por confirmar con Fernando:** el restaurante y el puesto son casetas de piezas simples (no un modelo completo de B2W2) en una posición fija cerca del centro de la plaza, lo que puede encimarse con otros edificios en pueblos muy compactos; todavía no existe una "rueda rápida" de objetos genérica en el juego, así que por ahora la tienda de campaña solo se usa desde la Mochila.

### Campamento en 3D (pedido de Fernando, 2026-10-10)
- "La tienda de campaña también debe ser 3D con el estilo del sistema, así como sus recursos y elementos, para que no parezca papel al dar la vuelta o ver la fogata."
- **Decisión:** modelos 3D propios de pocos polígonos con texturas pixel art como las de B2W2 (no hay tienda ni fogata en los modelos de B2W2): tienda de lona con postes y estacas, troncos con brasas y llamas cruzadas visibles desde cualquier lado, olla con tapa, troncos para sentarse y mochila.
- **También los campamentos de los NPC** viajeros, con los mismos modelos (lona de otro color).
- **Hecho** (`world/npc/camp.gd`: `tent_model`, `firepit` con olla y trípode en la tuya, tronco y mochila; lo usan los viajeros, tu tienda y el campamento abandonado de los puntos de interés). La tienda tiene colisión. Partidas viejas: el Kit Explorador se convierte en Tienda de Campaña al cargar.

### Ajustes tras la primera versión (decisiones de Fernando, 2026-10-10)
- **Restaurante:** con un modelo de edificio de B2W2 y letrero; el **puesto**, caseta 3D con toldo. **Por hacer.**
- **Rueda rápida de objetos — hecha** (`ui/quick_wheel.gd`, acción `quick_items`): mantener T (o la cruceta →; tocada sigue siendo zoom) abre la rueda con hasta 6 objetos (`GameState.quick_items`, se guardan con la partida); se apunta con el mouse o el stick y al soltar se usa. En la Mochila, cada objeto usable tiene "Poner en / Quitar de la rueda rápida". Empieza con la Tienda de Campaña y la Bicicleta. Íconos pixel art nuevos de la comida y la tienda (`tools/food_icons.py`; la soda es la oficial).
- **Pesca animada:** Nate saca la caña, el sedal vuela al agua, el corcho flota y se hunde con ondas al picar; al sacar, el pez o el Pokémon salta del agua. **Por hacer.**
- **Sprites de Cilan y Volkner:** Fernando pasará la verificación de Spriters Resource más adelante (siguen provisionales).
