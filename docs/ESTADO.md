# Estado del proyecto

Motor: Godot 4.7.2 estable (estándar, GDScript), instalado con Homebrew.

## Tabla de estado

| Fase | Estado | Commit | Notas |
|---|---|---|---|
| 0 | Hecha | ver `git log` (Fase 0: proyecto base) | `--quit` y `tests/smoke_test.tscn` en headless sin errores |
| 1 | Hecha (aprobada por Fernando el 2026-10-09) | `89ba4cc` | Nate animado, cámara libre y Pradera HD-2D con texturas de B2W2; 0 fallos; 60 FPS |
| 2 | Hecha (aprobada por Fernando el 2026-10-09) | `33a8792` | Hierba alta, salvajes con IA y compañero al azar; 0 fallos; 60 FPS |
| 2.5 | Implementada, esperando revisión de Fernando | ver `git log` | 5 pruebas en headless con 0 fallos; 55–60 FPS a 1080p; el mundo se construye en ~4 s |
| 2.8 | En curso | — | Pulido del mundo vivo (pedido de Fernando tras probar la 2.5) |
| 2.6 | Pendiente | — | Asentamientos, rutas pavimentadas y lugares icónicos (GDD 10c) |
| 2.7 | Pendiente | — | NPC con rutinas, viajeros, entrenadores caminando, día/noche y clima (GDD 10c) |
| 5.7 | Pendiente | — | Interiores (GDD 10c) |
| 5.8 | Pendiente | — | Actividades: pesca, Surf, hordas, equipo villano, bayas (GDD 10c) |
| 3 | Pendiente | — | — |
| 4 | Pendiente | — | — |
| 5 | Pendiente | — | — |
| 5.5 | Pendiente | — | Misiones, Piedra Llave, megapiedras y desbloqueos |
| 5.6 | Pendiente | — | Entrenadores NPC (GDD 10b) |
| 6 | Pendiente | — | — |
| 7 | Pendiente | — | — |

## Decisiones

- 2026-10-09: proyecto personal y privado. Se usan Pokémon reales y los sprites del paquete local `sprites/` (Pokémon Showdown).
- 2026-10-09: `sprites/` es solo fuente (con `.gdignore` y fuera de git). A `res://art/` se copian solo los sprites del roster.
- 2026-10-09: sprites gen5: `gen5ani` animado cuando existe y, si no, `gen5` estático con animación procedural. Hay 71 megas completas en estático.
- 2026-10-09: el jugador es Nate (`sprites/trainers/nate.png`).
- 2026-10-09: megaevolución una vez por combate (jugador y jefe), con Piedra Llave y megapiedra. Animación estilo X/Y.
- 2026-10-09: sin niveles ni experiencia. La progresión es por desbloqueo de habilidades y movimientos. Piedra Llave en un lugar fijo; megapiedras por misiones, en mundo abierto y sin orden obligatorio.
- 2026-10-09: se usan los 18 tipos oficiales con la tabla de efectividad oficial.
- 2026-10-09: el repo es propio, en `Pokemon/`. El repo raíz de LUMIA ya ignora esta carpeta.

## Fase 0 (proyecto base): hecha

1. `git init` en `Pokemon/`. `.gitignore` con `.godot/`, `sprites/`, `*.import` de builds y `export/`.
2. `.gdignore` en `sprites/` y en `docs/` para que Godot no los importe.
3. `project.godot` (4.7, Forward+, 1920×1080, 60 FPS) en la raíz, con la estructura de `res://` de la sección 4 del GDD más `art/pokemon/`.
4. Autoloads vacíos y tipados: `GameState`, `SaveSystem`, `InputHints` y `AudioBus`, en `core/`.
5. Input Map dual (teclado + mouse y mando): mover, cámara, correr, interactuar, esquivar, fijar objetivo, 4 ataques, capturar, apuntar, lanzar y menú.
6. Preset de importación pixel art por defecto: filtro Nearest, sin mipmaps y compresión sin pérdida.
7. Escena `tests/smoke_test.tscn`, que comprueba que los autoloads y las acciones existen y luego sale con código 0.
8. Verificar con `godot --headless --quit` y con la escena de prueba. Luego commit `Fase 0: proyecto base`.

Resultado:
- Godot 4.7.2. `project.godot` se genera con `tools/setup_project.gd` (`godot --headless --path . -s tools/setup_project.gd`).
- 23 acciones en el Input Map, cada una con teclado o mouse y con mando (incluye `mega_evolve`: G o cruceta arriba).
- Escena principal temporal: `world/main.tscn` (vacía).
- Material 3D base pixel art: `art/materials/pixel_base.tres` (Nearest).
- Prueba: `godot --headless --path . tests/smoke_test.tscn` sale con 0. La prueba negativa (una acción inexistente) sale con 1.

## Plan de la Fase 1 (jugador y Pradera en greybox)
1. Jugador `CharacterBody3D` (`world/player/`): caminar y correr relativos a la cámara, gravedad y salto desactivado; los parámetros van en un Resource `PlayerConfig.tres`.
2. Visual: `sprites/trainers/nate.png` copiado a `art/trainers/` (con un script en `tools/`), como `Sprite3D` billboard en eje Y, filtro Nearest, rebote procedural al caminar y blob shadow.
3. Cámara en tercera persona: `SpringArm3D` con pitch limitado a 35–45°, órbita con mouse (captura del cursor) y stick derecho, zoom limitado con rueda o cruceta, y suavizado.
4. Pradera greybox (`world/biomes/pradera.tscn`): terreno de unos 200×200 m con desniveles suaves, rocas y árboles low-poly con `pixel_base`, colisiones estáticas y límites invisibles.
5. `world/main.tscn` instancia la Pradera y al jugador; luz direccional y `WorldEnvironment` simple.
6. Pruebas en headless: `tests/test_player_movement.tscn` simula input (caminar, correr y mando) y comprueba desplazamiento, velocidad y que no atraviesa el terreno. Smoke test actualizado.
7. Verificación manual: abres el juego y lo pruebas con teclado y con mando. Commit `Fase 1:`.

## Fase 1: resultado
- Jugador: `world/player/` (`PlayerConfig.tres`): caminar a 4.5 m/s y correr a 8 m/s relativos a la cámara, velocidad constante en pendientes y stick analógico proporcional.
- Nate: billboard en eje Y con frente y espalda (la espalda se genera con `tools/make_back_sprite.py`), rebote al caminar y blob shadow (`Decal`).
- Cámara: `world/camera/camera_rig.tscn`. Pitch 35–45°, órbita con mouse (clic captura el cursor, Esc lo libera), stick derecho o flechas, zoom 4–11 m con rueda o cruceta.
- Pradera greybox: `world/biomes/pradera.tscn` con `BiomeConfig`. 200×200 m de terreno low-poly por ruido, con colisión exacta (trimesh), 40 rocas, 70 árboles, muros invisibles y un centro libre de 18 m.
- Sprites: `python3 tools/copy_sprites.py` regenera `art/` desde `sprites/` según `tools/sprites_manifest.json`.
- Prueba: `tests/test_player_movement.tscn`, con 15 comprobaciones: suelo, caminar, correr, frenar, frente y espalda, stick completo y a la mitad, recorrido por colinas sin atravesar el terreno, choque con un árbol y con el muro.

## Retroalimentación de la prueba manual (2026-10-09)
- La espalda generada de Nate no se ve bien. Se reemplaza por su sprite sheet overworld de B2W2 (caminar y correr en 4 direcciones).
- No hay animación de caminar ni de lado. Se resuelve con el sprite sheet overworld.
- Los árboles se ven pixeleados. Hecho: MSAA 4x + SMAA. Los árboles se reemplazan por modelos con follaje.
- La cámara no subía y no se sentía 360°. Hecho: órbita libre y pitch de -20° a 80°.
- Al mundo le faltaba estructura y textura. Primero se eligió el estilo Leyendas Arceus, pero al ver a Nate animado Fernando pidió que el mundo tuviera su mismo pixel art. Decisión final: HD-2D con gráficos de B2W2 (descargas autorizadas).
- Nate animado (hoja overworld de B2W2 de The Spriters Resource, ripeada por Dazz, "No Credit Required"): aprobado.
- Pokémon en el mundo: sprites overworld de seguidores (4 direcciones). En combate siguen gen5 / gen5ani.

## Mundo HD-2D (2026-10-09)
- Fuente: The Models Resource, B2W2 Route 01 (asset 587527), descargado en Chrome. Godot no importa bien el `.dae` ("Multiple instance_* not supported"), así que solo se usan sus texturas.
- Suelo: `world/terrain/terrain_pixel.gdshader`. Coordenadas del mundo a 17.5 px/m (igual que Nate); pasto, pasto claro, caminos de arena y tierra en pendientes, con bordes por dither de píxel; luz en escalones.
- Pinos como billboards con colisión (30 % a escala 2x). Flores, arbustos y mechones con MultiMesh sin colisión. Sprites sin sombreado (colores exactos).
- Ambiente: tonemap lineal, niebla ligera, brillo suave y desenfoque a distancia (DOF) en la cámara.
- Capas de colisión: 1 = terreno (la cámara choca), 2 = árboles y muros (solo bloquean al jugador).
- Descargados después (Chrome, con descargas múltiples permitidas por Fernando y URL directa `/media/assets/584/<id>.zip`): Floccesy Ranch, Pinwheel Forest y Twist Mountain. De ahí salen las rocas cafés, el árbol redondo y la lavanda de la Pradera.
- Apoyo en el suelo (pedido de Fernando): los sprites del mundo se recortan para que el dibujo toque su borde inferior; cada árbol, roca o decoración se apoya en la altura más baja de su base (centro y 8 puntos) y se hunde un poco (0.15 m los obstáculos, 0.05 m la decoración). Árboles y rocas llevan una sombra de contacto (Decal) que solo se proyecta sobre el terreno (los sprites van en la capa visual 2). Lo verifica una prueba que falla si algo flota (prueba negativa: detecta los 155 obstáculos subidos 0.5 m).
- Pendiente: la extensión de Chrome no tiene permiso en www.spriters-resource.com (Pokémon overworld, Fase 2).

## Recursos sugeridos por Fernando (para el arte del mundo, más adelante)
- Kenney.nl (Nature Kit, Prototype Kit) y KayKit: CC0.
- ambientCG (texturas de pasto, tierra y roca): CC0.
- Poly Pizza y OpenGameArt: la licencia varía por asset; revisar cada uno.
- Sonniss GDC Audio: licencia propia libre de regalías (no es CC0).
- Cada asset se registra en `CREDITS.md` con su URL y licencia.

## Decisiones de Fernando (2026-10-09, Fase 2)
- Roster aprobado.
- Inicial: 5 al azar de cualquier básico (no legendario); selección con huevos que eclosionan y luego Nate les lanza una Pokéball (pantalla en Fase 5). En la Fase 2 el compañero es un básico al azar.
- Evolución por desbloqueos (Fase 5.5); la mega llega con la forma final.

## Roster aprobado (los 18 tipos cubiertos, mezcla con y sin mega)
| Grupo | Pokémon | Tipos | Mega |
|---|---|---|---|
| Mundo (antes iniciales) | Venusaur | Planta/Veneno | Sí |
| Mundo (antes iniciales) | Charizard | Fuego/Volador | Sí (X e Y) |
| Mundo (antes iniciales) | Blastoise | Agua | Sí |
| Pradera | Pidgeot | Normal/Volador | Sí |
| Pradera | Ampharos | Eléctrico | Sí |
| Pradera | Sawsbuck | Normal/Planta | No |
| Pradera (rara) | Absol | Siniestro | Sí |
| Bosque/humedal | Heracross | Bicho/Lucha | Sí |
| Bosque/humedal | Swampert | Agua/Tierra | Sí |
| Bosque/humedal | Leavanny | Bicho/Planta | No |
| Bosque/humedal (rara) | Gardevoir | Psíquico/Hada | Sí |
| Montaña | Aggron | Acero/Roca | Sí |
| Montaña | Aerodactyl | Roca/Volador | Sí |
| Montaña | Excadrill | Tierra/Acero | Sí |
| Montaña (rara) | Froslass | Hielo/Fantasma | Sí |
| Jefe (bioma 3) | Garchomp | Dragón/Tierra | Sí |

Sprites verificados para los 16: mapa (pokeemerald-expansion, GitHub), frente y espalda gen5 animados, y mega.

## Plan de la Fase 2 (hierba alta y Pokémon visibles)
1. `tools/`: descarga de GitHub las hojas overworld del roster (32×32, 6 frames: abajo, arriba, lado) y las convierte a hojas de 4 direcciones con fondo transparente en `art/pokemon/<especie>/`. Créditos en `CREDITS.md`.
2. Datos: `PokemonType` (18), `SpeciesData.tres` (nombre, tipos, temperamento, rareza, velocidad, hoja overworld) y `EncounterTable.tres` de la Pradera.
3. Componente compartido `DirectionalSprite` (animación por dirección relativa a la cámara), reutilizado por Nate y por los Pokémon.
4. Hierba alta: parches con `MultiMeshInstance3D` (briznas pixel art de B2W2) que se mecen con el viento y se apartan al paso del jugador y de los Pokémon (shader con posiciones).
5. Spawner: los Pokémon aparecen visibles dentro de la hierba según la tabla de encuentro (máximo de vivos, desaparecen lejos del jugador).
6. IA salvaje (máquina de estados): deambular, curioso (se acerca), tímido (huye) y agresivo (persigue), según el temperamento de la especie.
7. Compañero: un Pokémon básico al azar (hasta que exista la selección de la Fase 5) te sigue con `NavigationAgent3D` (navmesh horneado del terreno y obstáculos), esquiva árboles y rocas, tiene idle y mira a los salvajes cercanos.
8. Pruebas en headless (spawner, IA, seguimiento) y medición de FPS con la hierba; commit `Fase 2:`.

## Fase 2: resultado
- Datos: `tools/build_species.py` genera 436 especies (`creatures/data/species/*.tres`) desde PokeAPI con las hojas overworld de pokeemerald-expansion. Grupo de iniciales: 423 básicos (sin legendarios, singulares, Ultraentes ni paradojas). Tabla de la Pradera: Pidgeot 35, Ampharos 30, Sawsbuck 30 y Absol 5 (raro), máximo 12 vivos.
- `DirectionalSprite`: animación por dirección compartida por Nate y los Pokémon.
- Hierba alta: 16 parches (el primero a 26 m del inicio), unas 18,000 briznas con MultiMesh; shader con viento y se aparta y aplasta al paso de hasta 16 actores.
- Navegación: horneada al iniciar desde terreno, árboles, rocas y muros (celdas de 0.5 m).
- `PokemonActor`: rol salvaje (deambula, curioso, tímido o agresivo, con contacto que avisa del encuentro) y rol compañero (sigue con navegación, corre si te alejas, reaparece si se queda a más de 30 m y mira al salvaje más cercano).
- `WildSpawner`: aparecen solo en hierba alta, a más de 10 m del jugador; desaparecen a más de 90 m.
- Capas de colisión: 1 terreno, 2 obstáculos, 3 actores (jugador y Pokémon no se empujan; la cámara solo choca con el terreno).
- Prueba: `tests/test_creatures.tscn`. Mide la navegación, el seguimiento del compañero, la aparición en hierba y los 4 temperamentos (agresivo 7→0 m con contacto, tímido 6→16 m, curioso 7→2.4 m y deambula sin contacto).

## Plan de la Fase 2.5 (pedido de Fernando, 2026-10-09; adelanta los biomas de la Fase 6)
Decisiones de Fernando:
- Especies: todas (1,025), aparecen según su tipo y bioma. El roster de 16 queda como destacados.
- Agua: lago en la Pradera, río que baja de la montaña y cruza los tres biomas, pantano en el Bosque y costa (mar) en un borde.
- Rareza: peso = etapa × poder. Básico ×1, 2.ª etapa ×0.35, 3.ª etapa ×0.1; a más estadísticas totales, menos probable (más de 500, muy raro).
- Legendarios (todos): cada uno en un lugar fijo según su tipo, uno a la vez y moviéndose en su zona. Tras capturarlo puede reaparecer con 2 % de probabilidad, nunca más de uno.
- Shiny: 2 %, con paleta variocolor en el mapa y en combate, y un destello periódico.
- Tamaño por altura oficial en escalones de píxel: ×1, ×1.5, ×2 y ×3.
- Persecución: agresivos (te persiguen al verte) y territoriales (solo dentro de su zona). Área según el Pokémon (12–35 m, base 20) con indicador en el suelo; si te alcanza empieza el combate; si sales del área se rinde y regresa.
- Correr con stamina: barra de aguante que se gasta corriendo y se recupera caminando.
- Los 3 biomas se adelantan ahora, antes del combate.

Pasos:
1. Datos: las 1,025 especies con etapa evolutiva, estadísticas totales, altura (escalón de tamaño), bandera legendario/singular y hoja shiny (paleta `overworld_shiny.pal` de pokeemerald).
2. Mundo: Pradera (centro), Bosque/humedal y Montaña conectados en un solo terreno, sin cargas; río, lago, pantano y costa con agua animada (textura de B2W2); el agua profunda bloquea el paso.
3. Hábitats por tipo (pradera, bosque, montaña, agua dulce, mar, pantano) y spawner por zona con la rareza y el 2 % de shiny.
4. Persecución (agresivo y territorial), área con indicador, stamina del jugador con barra en pantalla.
5. Legendarios en lugares fijos con la regla de reaparición.
6. Pruebas en headless y capturas.

## Fase 2.5: resultado
- Datos: 1,025 especies (`tools/build_species.py`): hábitats por tipo (los de Agua solo en agua; los nadadores por forma de pez, serpiente o tentáculos), peso = etapa × poder (roster ×20 en su bioma, salvo sus raros), tamaño ×1, ×1.5, ×2 o ×3 por altura, y hoja shiny con la paleta `overworld_shiny.pal`.
- Mundo (`world/world_builder.gd` + `world/world_config.tres`): 480×480 m sin cargas. Pradera (centro y este), Bosque/humedal (oeste, con pantano de 10 charcas), Montaña (norte, crestas) y costa con mar (sur). El río (curva Catmull-Rom) baja de la montaña, cruza el bosque, pasa por el lago y llega al mar. Suelo con un shader por bioma (`terrain_world.gdshader`) y bordes de píxel con dither.
- Agua sin flotar (pedido de Fernando): cada cuerpo de agua tiene cauce y ribera. El nivel sale del terreno más bajo a su alrededor, la superficie termina dentro de la ribera (borde enterrado) y tierra adentro nunca queda bajo el nivel del mar. `tests/test_world.tscn` revisa 277 puntos de borde (el peor queda 5 cm bajo el terreno).
- Spawner por hábitat (hierba, orilla y agua), shiny 2 % con destello, legendarios (94) en lugares fijos según su tipo, uno a la vez, con la reaparición del 2 % en `GameState`.
- Persecución: agresivos y territoriales; área de 12–35 m según velocidad y poder, con anillo en el suelo; al salir del área se rinden y regresan.
- Stamina (barra en pantalla): correr 5 s la agota y hay que recuperar el 25 % para volver a correr. El agua profunda detiene a Nate en la orilla.
- Rendimiento: construcción de 21 s a 4 s (alturas en caché), sombras del sol y desenfoque más baratos; de 51 a 55–60 FPS a 1080p en M1.

## Fase 2.8: decisiones de Fernando (2026-10-09)
- Arreglar tirones y sprites rotos.
- Aparición en cualquier lugar (no solo en hierba alta), con cupo por zona de 40×40 m y especies características por zona. Los Pokémon tienen mentalidad propia y recorren todo.
- Manadas en el 30 % de las apariciones: 3 a 6 de la misma línea evolutiva, la mayoría básicos, y rara vez un líder evolucionado (más grande). Nunca dos manadas juntas, salvo un 5 %, y entonces pueden pelear según su naturaleza.
- Esconderse: tras 1 a 3 minutos sin interacción buscan un escondite y desaparecen con un efecto según el lugar (hojas, polvo, salpicadura, arena).
- Peleas entre salvajes: rivalidades naturales (ventaja de tipo, agresivos contra débiles, territoriales contra intrusos, manadas rivales y enemigos clásicos), con barra de vida visible. El ganador queda herido. Al debilitarse quedan aturdidos 5 s (estrellitas girando); si no se capturan en ese tiempo, desaparecen en humo (estilo mob de Minecraft).
- Captura en el mundo estilo Leyendas Arceus: apuntar (clic derecho o LT) con arco de trayectoria y lanzar (clic izquierdo o RT). La probabilidad usa el ratio oficial de la especie, su vida, la Pokéball, su temperamento y un bono por sigilo. Se mantiene la captura en primera persona dentro del combate.
- Salto: Espacio o B (Círculo) explorando; en combate ese botón es la esquiva (salto o dash).
- Legendarios solo en santuarios, con 10 % por visita y a veces condición de hora o clima. Pseudolegendarios solo en su zona, 10 veces más raros (y su etapa final, casi nunca).
- Minimapa que gira con la cámara y mapa completo (M o Select) con niebla de exploración y marcadores.
- Coherencia: pisos de altura en la montaña (pinos, roca, nieve), transiciones naturales, ribera viva (juncos, árboles, flores; pantano con árboles muertos y niebla) y caminos que conectan lugares.
- Documentación: al cerrar la fase, reorganizar en un .md por tema (regla nueva).
- Orden: tirones y sprites, aparición y manadas y esconderse y legendarios, salto, coherencia, peleas, captura y mapa.
- Legendarios cautelosos (pedido posterior): nunca atacan; si te ven (cono de visión) o te oyen (cerca, o más lejos si corres) muestran "?" y se reubican rápido: los voladores levantan el vuelo y los demás corren a un lugar seguro.
- Pedidos posteriores, pendientes de detallar: vida del jugador (ataques de salvajes al jugador y a su compañero, caída desde altura, ahogarse en el agua al quedarse sin aire, estilo Minecraft); Pokémon Bicho colgados en los árboles que caen de sorpresa y aves en las copas que se lanzan en picada, según su naturaleza.

### Avance 2.8 (bloques 1 y 2)
- Sprites rotos: 25 hojas usan cuadros de 64 px (Lugia, Reshiram…) y 52 traen el lado derecho propio (8 cuadros, sprites asimétricos como Absol). El conversor detecta ambos y el tamaño en el mundo se normaliza (32 px × escalón).
- Tirones: los Pokémon recalculaban su camino en cada cuadro (ahora solo si el destino se mueve más de 1.5 m) y los efectos compilaban su shader la primera vez (ahora hay un calentamiento al cargar). En 60 s con 27 salvajes: de 27.2 a 16.7 ms de promedio y de 854 a 29 ms de peor cuadro.
- Aparición en cualquier lugar transitable (ajustado a la navegación, nunca dentro de árboles, rocas ni agua), con zonas de 40 m, cupo de grupos por hábitat y 2 especies características por zona (35 % de las apariciones).
- Manadas (30 %): de 3 a 6 de una línea evolutiva, con líder evolucionado en el 25 % de las manadas. Siguen al líder en formación y huyen o persiguen juntos. Separadas 60 m, salvo un 5 % de manadas rivales a 15 m.
- Mentalidad propia: pasean hasta 14 m y cada 4 paseos se mudan unos 25 m.
- Esconderse: tras 60–180 s sin interacción buscan hierba alta cercana y desaparecen con una nube (`world/effects/pixel_burst.gd`): hojas, hojas de bosque, polvo, roca, salpicadura, arena o humo. La manada se esconde con su líder.
- Pseudolegendarios: solo en montaña, ×0.1 y su etapa final ×0.01. Datos nuevos: línea evolutiva y ratio de captura oficial.
- Legendarios: 10 santuarios (la cumbre más alta incluida), 10 % de aparición por visita y uno a la vez por especie. Cautelosos, con "?" y escape corriendo por un camino real o volando en arco (Volador o dragón grande). Nunca provocan combate.


## Pendiente de definir
- Entrenadores NPC (GDD 10b), Fase 5.6: qué recompensa dan y si vuelven a retar.
- Detalle de misiones y desbloqueos (Fase 5.5).
