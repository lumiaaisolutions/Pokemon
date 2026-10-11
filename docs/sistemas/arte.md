# Dirección de arte y assets

[← Índice](../README.md)

## Estilo
- **HD-2D con gráficos de Pokémon Negro 2/Blanco 2** (decisión final del 2026-10-09). Se descartaron el greybox low-poly y el estilo naturalista de Leyendas Arceus.
- Suelo 3D con texturas pixel art de B2W2; **todo el mundo es 3D de pocas caras salvo los Pokémon, los personajes y los NPC**, que siguen siendo sprites billboard (eje Y) — regla 1 de [reglas_calidad.md](../reglas_calidad.md), 2026-10-10. Ver "Todo el mundo en 3D" más abajo.
- Todo comparte el mismo tamaño de píxel: **0.057 m/px (≈17.5 px/m)**, el de Nate.
- Sprites sin sombreado (colores exactos de B2W2) y suelo con luz en escalones (cel).
- Ambiente: tonemap lineal, niebla ligera, brillo suave y desenfoque a distancia (DOF de calidad baja).
- Anti-aliasing MSAA 4x + SMAA para la geometría 3D.

## Fuentes (detalle en [`CREDITS.md`](../../CREDITS.md))
| Uso | Fuente |
|---|---|
| Nate (caminar y correr, 4 direcciones) | Spriters Resource, B2W2, hoja overworld ripeada por Dazz |
| 10 personajes jugables | Red, Ethan, Lyra (HGSS); Lucas, Dawn (Platino); Brendan (hyo-oppa, estilo DPPt); May, Serena, Leaf (Zender1752, estilo Gen 5); Calem (TOBALCR, estilo BW). Red, Calem, Leaf, May y Serena no traen correr: corren con su caminar acelerado. Calem se ve un poco más alto que el resto (así está dibujado) |
| Megas en combate | 97 megas (`tools/build_megas.py`): 70 con sprites Gen 5 completos (incluida Mega Greninja); 27 de Leyendas Z-A y su DLC sin sprite Gen 5 en el dump |
| Texturas del mundo | Models Resource, mapas de B2W2: Route 01, Floccesy Ranch, Pinwheel Forest, Twist Mountain (solo las texturas: Godot no importa sus `.dae`) |
| Pokémon en el mundo (1,025, normal y shiny) | pokeemerald-expansion (GitHub): `overworld.png` + `overworld_shiny.pal` |
| Pokémon en combate (Fase 3) | Paquete local de Pokémon Showdown (`sprites/gen5`, `gen5ani`, `-back`, `-shiny`; 71 megas completas en estático) |
| Datos de especies | PokeAPI (CSV en GitHub) |

## Reglas del pipeline
- `sprites/` es la **fuente local** (1.1 GB, con `.gdignore` y fuera de git). A `art/` solo se copia lo que usa el juego, y eso sí se versiona.
- `tools/copy_sprites.py` + `tools/sprites_manifest.json`: copia y recorta los sprites del mundo y de Nate. Los recortes eliminan el relleno transparente para que el dibujo toque su borde inferior.
- `tools/overworld_sheet.py`: hojas de B2W2 (celdas sobre fondo magenta) a hojas limpias.
- `tools/build_species.py`: genera las 1,025 especies y sus hojas. Detecta cuadros de 32 o 64 px y los 8 cuadros con el lado derecho propio (sprites asimétricos).
- `tools/derived_sprites.py`: sprites derivados (árbol muerto del pantano).
- `tools/protagonist_sheets.py`: convierte las 10 hojas de personajes (de distintos formatos) al formato de Nate (3 × 8 celdas de 32 px, pies abajo y cabeza centrada). Las fuentes están en `sprites/overworld/protagonists/`. La dirección de cada fila se verificó midiendo de qué lado queda la piel de la cara.
- `tools/snapshot.tscn`: captura una escena con el render real para revisar cómo se ve (`godot --path . tools/snapshot.tscn -- <escena> <salida.png> [cuadros] [personaje] [paso] [desmayo]`).
- Otros assets de terceros solo con licencia CC0, registrados en `CREDITS.md`.
- Recursos sugeridos por Fernando para más adelante: Kenney y KayKit (CC0), ambientCG (CC0); Poly Pizza y OpenGameArt (licencia variable); Sonniss GDC Audio (licencia propia, no es CC0).

## Arte generado para el mundo grande (2026-10-10)
- `PropArt` (`world/region/prop_art.gd`): cactus, palmera, hongo gigante, hongo luminoso (brilla de noche), acacia y corales, con contorno oscuro estilo B2W2.
- Edificios y lugares con piezas de colores (cajas, prismas y cilindros) en `Structures`: techos rojos del Centro, azules de la Tienda, gimnasios del color de su tipo.
- Sprites de MT, Safari Ball, Leche Mu-mu y fósiles desde el paquete de íconos (`sprites/itemicons/`).
- Uniformes globales: `time_tint` (hora) y `season_tint` (estación) para el pasto, la hierba alta y el follaje; los sprites tienen `glow` (luz propia) y `seasonal` (follaje).
- Bicicleta pixel art generada (`Player._bike_texture`).

## Todo el mundo en 3D (2026-10-10, noche)
Regla 1 de [reglas_calidad.md](../reglas_calidad.md): árboles, rocas, arbustos, flores,
cactus, hierba alta, cofres, troncos, recolectables y lugares de interés dejan de ser
sprites/`QuadMesh` planos. Solo siguen siendo sprites los Pokémon, los personajes y los NPC
(billboard, `sprite_billboard.gdshader`, sin tocar).

### Qué había realmente en los mapas de B2W2 descargados
Al revisar `art/models/b2w2_nature/b2w2map_*.dae` con la herramienta de extracción
(`tools/extract_b2w2_props.gd`) se encontró que **los árboles, la hierba y las flores de
B2W2 no son piezas 3D sueltas**: están pintados como superficies dentro de la malla del
terreno de cada mapa (submallas con mallas con huesos/`skin` por material, p. ej.
`ki02ax`/`ki02bx`/`ki02c`/`ki02dx` para los pinos, `kusa_ec1/2/3` para la hierba,
`hana01_1` para las flores). Extraer esas piezas como objetos sueltos resultó poco fiable
(el importador de Godot reestructura el esqueleto y las mallas no se separan de forma
limpia). Lo que **sí** son objetos sueltos y reales en 3D: `rock_01`/`rock_02`/`searock_01`
(rocas, dentro de los mapas, con el patrón `object_NN_<nombre>`) y 16 modelos sueltos de un
solo `.dae` en `art/models/b2w2_nature/b2w2obj_*` (2 árboles muertos, 2 tocones, el árbol
grande del bosque blanco, roca azul, roca de cueva, cerca, santuario, 4 letreros y 3
faroles) — estos se usan tal cual, igual que `BuildingModels`.
Decisión (ver [decisiones_sin_preguntar.md](../decisiones_sin_preguntar.md)): para el
resto del follaje y las rocas decorativas, "3D propio de pocas caras con textura pixel"
(la cláusula de la regla 1 para lo que no existe como modelo suelto), reusando las mismas
texturas pixel que ya tenía el juego (no sprites nuevos).

### `PropModels3D` (`world/region/prop_models.gd`)
- **Modelos reales sueltos** (`instance(kind)`): los 16 `b2w2obj_*` de arriba, cargados y
  centrados igual que `BuildingModels` (escala 0.08, materiales con filtro de píxel y
  recorte de alfa). Los troncos muertos del pantano, pantano tóxico, bosque oscuro y
  volcán alternan entre los dos árboles muertos reales.
- **Follaje 3D de verdad** (`foliage_mesh`, antes `cross_mesh` — reemplazado 2026-10-11, ver
  detalle más abajo): tronco + copa de volúmenes reales (pocas caras, perfil distinto por
  tipo/bioma), nunca plano desde ningún ángulo (ni siquiera desde arriba, el problema de la
  antigua cruz de 2 planos). Lo usan los árboles, arbustos, flores, cactus, palmeras,
  hongos, juncos y la hierba alta; los nenúfares siguen con `pad_mesh` (horizontal con
  grosor, no necesitaba el cambio).
- **Rocas** (`rock_mesh`): la misma malla irregular de `BreakableRock.rock_mesh` (pocas
  caras, octaedro con vértices al azar) con color plano en vez de textura; 10 formas fijas
  reusadas en todo el mundo (no una malla nueva por roca: en un mundo de 4×4 km con miles
  de rocas eso crecería sin límite en memoria).
- **Troncos/conchas/huesos** (`log_mesh`, `shell_mesh`, `bones_mesh`): primitivas simples
  (cilindro, cono, cajas cruzadas) con color plano.
- **Cerca de campo** (`fence_mesh`): el modelo real de B2W2 (`BuildingModels` "fence"),
  fundido en una sola malla para repetirlo en `MultiMesh`.
- **Tablillas/letreros/boca de cueva** (`plaque_mesh`): lámina de pie con grosor (frente y
  atrás con la textura), no un cartel plano.

### Material y luz (`world/effects/foliage_material.gdshader`, `FoliageMaterials`)
Las mallas de follaje usan luz normal (seguían con `sprite_billboard.gdshader`, que es
`unshaded`): ahora los árboles y plantas se oscurecen de noche con el resto del mundo sin
necesitar código aparte (la luz direccional ya baja de noche, ver `day_night.gd`). El tinte
de estación (`season_tint`, antes solo en los sprites) se conserva igual en todo el árbol
(tronco y copa juntos, como el sprite original), con el mismo uniforme global. Las rocas y
troncos usan `StandardMaterial3D` con color plano (no son follaje, no cambian con la
estación).

### Hierba alta (`world/terrain/tall_grass_3d.gdshader`)
Reemplaza `tall_grass.gdshader` (billboard): la mata es un mechón de hojas en V con grosor
real (`PropModels3D.foliage_mesh(..., "tuft")`, ver más abajo) en el mismo
`MultiMeshInstance3D` de antes. El viento y el empuje de los actores cercanos siguen igual
(mismos uniformes `actors[16]`, `push_strength`), solo que el desplazamiento se aplica
directo sobre los vértices reales en vez de reconstruir un plano orientado a cámara.

### Follaje 3D de verdad (2026-10-11, rama `follaje`)
Revisión de Fernando tras probar el mundo en 3D: la "cruz de 2 planos" del follaje (dos
planos perpendiculares con la textura del árbol/arbusto/flor completo) se veía bien desde
los lados pero **plana desde arriba** (cada plano tiene grosor 0 en su propio eje; mirando
en picada solo se ve una cruz delgada, sin relleno) — justo lo que pide evitar la regla 1.
Se reemplaza por `PropModels3D.foliage_mesh` (antes `cross_mesh`): tronco + copa de
volúmenes reales, pocas caras, con un perfil distinto por tipo/bioma.

**Segunda vuelta (mismo día):** la primera versión envolvía la textura completa del árbol
(un dibujo de frente, como `tree_round.png`) alrededor de un tambor facetado — eso corta la
imagen en tajadas verticales que, unidas, no se parecen al dibujo original (Fernando: "los
árboles actuales NO tienen estilo BW2"). La solución real, mirando cómo arma B2W2 sus
propios árboles (`tools/extract_b2w2_props.gd` sobre los mapas .dae): el árbol completo NO
es una sola imagen envuelta, es un **tronco corto marrón liso + varias burbujas de hoja
("puffs") casi redondas superpuestas**, cada una con su propio sprite pequeño y
razonablemente parecido desde cualquier lado — eso sí se puede envolver sin que se note el
corte.

- **Texturas reales de B2W2 extraídas de los mapas** (`art/world/b2w2_leaf/`, créditos ya
  cubiertos en `CREDITS.md` como "Models Resource, mapas de B2W2"): `tree_round_real.png`
  (ki03ax, Floccesy Ranch) y `tree_pine_real.png` (ki02ax, Pinwheel Forest) son el árbol
  completo de referencia (para comparar); los que de verdad se usan como puffs son
  `puff_round_dark/light.png` (ki03bx/ki03dx) y `puff_forest_dark/light.png`
  (ki02bx/ki02dx) — cada uno, una sola burbuja de hoja redonda. Lienzo 32×64 (no 32×32):
  el dibujo real ocupa solo la mitad de abajo, para que el tamaño del árbol (que sale del
  tamaño en píxeles de la textura, igual que el resto del follaje) salga alto como
  ki03ax/ki02ax y no cuadrado. Cada textura trae además un parche de 4×4 px en la esquina
  (siempre transparente en un blob redondo) con un marrón de tronco a ojo — así
  `PropModels3D._sample_uv` puede sacar un color de tronco real sin necesitar una segunda
  textura/material.
- **Tronco:** prisma corto de 6 caras (`_revolve`), con un solo color plano sacado de ese
  parche (`solid_uv`, no envuelve nada — un tronco liso no tiene "lados" que cortar).
- **Copa ("puffs"):** `PropModels3D._puff` es una burbuja achatada de pocas caras
  (`PUFF_PROFILE`, revolución que se abre y cierra en punta) con el sprite de hoja
  envuelto. Varias burbujas superpuestas (una grande + 2-3 chicas alrededor, más una extra
  en bosque) arman la copa en capas/bloques, regordeta (ancho ≈ alto) como el árbol de
  pradera de B2W2. `_puff_uv_range` calcula, una vez por textura, qué franja vertical tiene
  dibujo real (cada sprite deja un margen transparente distinto): si una burbuja llegara a
  muestrear ese margen, el recorte de alfa del shader la volvía invisible — el "hueco" que
  separaba la copa del tronco en una vuelta intermedia de este cambio.
- **Perfil por tipo** (`_tree_shape` en `world_builder.gd`, decide por bioma porque el mismo
  slot de textura de `BiomeConfig` se reusa en varios biomas): **pradera** (`round`, una
  burbuja grande + 3 chicas, regordeta), **bosque** (`forest`, igual pero más densa/alta,
  con una 4.ª burbuja), **pino/nevado** (`pine`, 4 burbujas achatadas apiladas en el mismo
  eje, cada una más chica que la de abajo — silueta cónica por capas como ki02ax), **jungla**
  (mezcla de `forest` + palmeras), **pantano** (mezcla de `forest` + troncos secos),
  **árbol seco** (`dead`, tronco alto + ramas finas en abanico, `_branch_cluster`),
  **palmera** (`palm`, tronco curvo + 7 pencas en V reales que salen de la copa,
  `_palm_fronds`/`_blade` — hojas arqueadas de verdad), **acacia** (`acacia`, copa ancha y
  achatada), **hongo gigante** (`mushroom_giant`, tallo + sombrero ancho, bioma hongos).
- **Cactus, acacia, hongos, arbustos y flores:** siguen con `_revolve`/`_branch`, pero ahora
  con `solid_uv` (color plano sacado de la textura real, no envuelto): son dibujos de frente
  sin la simetría redonda de un puff, así que envolverlos seguía cortándolos en tajadas; el
  color sí sale de la textura real (`_sample_uv`), igual que rocas/troncos/conchas ya hacían.
- **Hierba alta, juncos/cattails, coral, cristal y hongos chicos:** mechones/ramitas en V
  con grosor real (`_blade`/`_blade_cluster`/`_branch_cluster`): cada hoja es un "libro
  abierto" de 2 caras que se encuentran en un filo desplazado hacia adelante — con volumen
  real desde cualquier ángulo, no un plano. (Pendiente para una siguiente pasada: usar
  también el sprite real `tuft_real.png`/`flower_real.png` extraído de B2W2, ver "Qué
  quedó fuera" más abajo.)
- Los árboles lejanos (`FarTrees`, sin colisión) usan una versión barata de muy pocas caras
  (`cheap = true`, ahora también con `solid_uv`) en vez de la forma completa, para no subir
  el costo por instancia en el `MultiMesh` que más se repite.
- Todo sigue usando `FoliageMaterials`/`foliage_material.gdshader` sin tocar (luz normal,
  `season_tint`, `glow`): lo único nuevo es la malla, no el material.
- Las posiciones, semillas (`props_seed`), colisiones (`StaticBody3D` + `CylinderShape3D`,
  sin cambios), el tinte de estación y los Pokémon posados (`AmbushManager`/
  `PokemonActor._in_front_of_canopy`, que solo lee `obstacle_height` del meta, no la forma
  de la malla) quedan exactamente igual que antes.
- `tests/test_no_flat_vegetation.gd` se amplió con `_check_volume`: ninguna malla de
  vegetación (árboles, rocas, decoración, hierba alta, árboles lejanos, bases de
  recolección) puede tener una caja local con grosor ~0 en algún eje.
- Herramienta de revisión: `tools/snapshot.tscn` ganó `pitch:N` y `zoom:N` como argumentos
  de `bioma:NOMBRE` (antes solo `giro:N`), y `tests/_tmp/tree_preview.tscn` (no se
  versiona) arma un solo `PropModels3D.foliage_mesh` de cerca, sin el resto del mundo, para
  comparar contra las texturas/mapas de B2W2 sin ruido.

### Rendimiento
Los árboles/rocas individuales (con colisión propia) siguen siendo un `StaticBody3D` por
pieza, igual que antes (mismo costo). La decoración, la hierba y los árboles lejanos (LOD)
siguen en `MultiMeshInstance3D` con `visibility_range_end`, igual que antes — el cambio es
la malla que dibuja cada instancia (un tronco+copa de unas pocas decenas de triángulos, o
una versión barata de ~15 triángulos para los árboles lejanos, en vez de la cruz de 8
triángulos o el plano de 2), no la cantidad de llamadas de dibujo. Las mallas de
`PropModels3D` se cachean por forma/textura/tamaño de píxel (no por instancia) para no
multiplicar el uso de memoria con miles de copias del mundo. Medido con
`tests/_tmp/fps_probe.gd` (no se versiona) en bosque (denso en árboles/hierba nuevos) en
esta Mac M1: ver la nota de la siguiente revisión de rendimiento en
[plan_pulido_mundo.md](../plan_pulido_mundo.md).

### Pokémon posados en árboles (`world/actors/ambush_manager.gd`, `pokemon_actor.gd`)
Los árboles ya no son billboards que se inclinan al mirar desde arriba
(`sprite_billboard.gdshader`), así que el Pokémon posado ya no necesita seguir esa
inclinación cuadro a cuadro: `PokemonActor._in_front_of_canopy()` ahora solo aplica un
empujón fijo hacia la cámara (antes seguía la fórmula del tilt del shader). La altura del
árbol para decidir dónde posarse/colgar ya no sale de un `Sprite3D` (no existe): queda en
`StaticBody3D.set_meta("obstacle_height", ...)` al construirlo (`WorldBuilder._obstacle`),
y `AmbushManager.tree_height()` la lee de ahí.

### Cofres 3D (`world/poi/chest_3d.gd`)
Madera de pocas caras con herrajes metálicos (franjas y candado), bisagra que gira al
abrir, destello y chispas doradas (decisión de Fernando, 2026-10-10). Tres variantes fijas
por el id del campamento (`Chest3D.tier_for`): común (madera, 68 %), raro (plata, 20 %) y
legendario (oro, 6 %), con mejor botín según el nivel
(`PointsOfInterest.CHEST_LOOT_BY_TIER`).

### Revisión visual y rendimiento (2026-10-10, noche)
Capturas con el render real (`tools/snapshot.tscn`, opción nueva `bioma:<NOMBRE>`, ver
docs/herramientas.md) en bosque (día y noche, girando a 35°), desierto, pantano y montaña:
árboles con volumen real (ya no planos), hierba alta en matas 3D, nenúfar en la charca del
pantano, rocas y follaje que se oscurecen de noche solos (antes el shader de sprite era
`unshaded` y no les afectaba). Pendiente para una siguiente pasada: capturas de los biomas
restantes (bosque oscuro, hongos, flores, pantano tóxico, nieve/tundra, cañón, meseta,
playa, volcán, jungla) y una revisión más de cerca de proporciones (algún árbol/roca podría
verse mejor un poco más grande o más chico a ojo).
FPS: sonda en bosque (denso en árboles/hierba nuevos) con `tests/_tmp/fps_probe.gd` (no se
versiona): promedio 85.9 FPS, mínimo 19.0 FPS — medido en esta Mac M1 **con el sistema muy
cargado** (7–8 procesos de Godot de otros agentes trabajando en paralelo a la vez), así que
el mínimo real de un jugador solo es más alto; no hay una medición "antes" para comparar
(los sprites billboard de antes no tenían un costo muy distinto: menos triángulos por
instancia pero el mismo número de objetos y de MultiMesh).

### Qué quedó fuera de esta pasada
- Los íconos pequeños que acompañan a un objeto 3D (las bayas sobre el árbol grande, los
  minerales/conchas que se recogen en `GatherManager`, el tesoro de mazmorra) siguen como
  sprite: son del mismo tipo que un objeto en la mano, no vegetación ni mobiliario.
  `tests/test_no_flat_vegetation.gd` los excluye a propósito.
- Capturas de los biomas que faltan (ver arriba) y una medición de FPS sin otros agentes
  corriendo a la vez, para un número comparable de verdad.
- Hierba alta/matas de piso y flores siguen con la textura actual (`tuft.png`/PropArt),
  no con los sprites reales extraídos `tuft_real.png`/`flower_real.png` (ya en
  `art/world/b2w2_leaf/`, sin usar todavía): Fernando pidió aplicar el estilo BW2 "lo mismo"
  a hierba/flores, pero el tiempo de esta pasada se fue en el rediseño de los árboles
  (que era lo explícitamente roto). Cactus, acacia y hongo gigante tampoco tienen un sprite
  real de B2W2 equivalente (son arte propio generado por código, ver `PropArt`): se
  arregló que ya no se cortan en tajadas (`solid_uv`), pero su silueta/estilo no se revisó
  a fondo contra una referencia BW2.
