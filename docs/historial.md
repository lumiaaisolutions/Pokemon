# Historial por fase

[← Índice](README.md) · Los detalles técnicos actuales están en [sistemas/](sistemas/); aquí queda qué se hizo en cada fase y por qué cambió.

## Fase 0 — Proyecto base (`1f40246`)
Repo propio, Godot 4.7.2, estructura de carpetas, 4 autoloads, Input Map dual (teclado + mando), importación pixel art, `tools/setup_project.gd` y prueba de humo (con prueba negativa).

## Fase 1 — Jugador y primer bioma (`362778e` → `89ba4cc`)
- Primer intento en greybox low-poly con Nate estático y espalda generada. Tras la prueba de Fernando: la espalda no convenció, faltaba animación, los árboles se veían dentados y la cámara se sentía limitada.
- Cambios: hoja overworld de Nate (B2W2) con 4 direcciones, cámara libre de 360° (−20° a 80°) y anti-aliasing.
- Se probó un mundo estilo Leyendas Arceus y se descartó: Fernando pidió el mismo pixel art que Nate. Decisión final: **HD-2D con texturas de B2W2** (descargadas en Chrome; Cloudflare bloquea curl).
- Apoyo en el suelo: nada flota (recorte de sprites, base más baja, sombra de contacto y una prueba que lo verifica).

## Fase 2 — Hierba y Pokémon visibles (`33a8792`)
Datos desde PokeAPI con sprites de pokeemerald-expansion, `DirectionalSprite` compartido, hierba alta con MultiMesh y shader, navegación horneada, IA por temperamento, compañero al azar entre los básicos. Roster de 16 aprobado; iniciales al azar con huevos y evolución por desbloqueos.

## Fase 2.5 — Mundo de 3 biomas (`cadf095`)
Mundo de 480 m con pradera, bosque/pantano, montaña y costa, río y lago; 1,025 especies por hábitat y rareza; shiny; tamaños; persecución con área y stamina; legendarios en lugares fijos. Tras la prueba de Fernando, **el agua flotaba**: se rehízo con cauce y ribera, borde enterrado y una prueba de 277 puntos. Rendimiento: construcción de 21 s a 4 s.

## Fase 2.8 — Mundo vivo (implementada, esperando revisión)
Pedido tras probar la 2.5 (tirones, sprites rotos, aparición solo en hierba, demasiados legendarios):
1. **Sprites y tirones** (`8c0f14f`, `5b97ccd`): hojas de 64 px y lado derecho propio; caminos recalculados solo si el destino cambia; calentamiento de shaders. De 27 a 16.7 ms de promedio y de 854 a 29 ms de peor cuadro.
2. **Aparición, manadas, esconderse y legendarios** (`8c0f14f`): en cualquier lugar con cupo por zona, manadas de una línea evolutiva, escondite con efecto, legendarios en santuarios y cautelosos (pedido posterior de Fernando).
3. **Salto, vida, caídas, agua y desmayo** (`bff7a63`): pedido posterior estilo Minecraft.
4. **Coherencia de biomas** (`c6dee03`): nieve y roca por altura, caminos que conectan, borde del bosque, ribera viva y pantano.
5. **Peleas** (`0a228c3`) y **emboscadas** (`6d90c25`): rivalidades, aturdido y humo, ataques al jugador, defensa y guardia del compañero; Bicho que caen y aves en picada.
6. **Captura en el mundo** (`7d8ca04`): apuntar y lanzar con física, fórmula oficial, sigilo y aturdido. Además, la documentación se reorganizó en un `.md` por tema.
7. **Mapa**: minimapa que gira con la cámara y mapa completo con niebla de exploración.

Problemas encontrados y corregidos en el camino: un río colgado sobre laderas, charcas encimadas, manadas con especies de otro hábitat (Marill en la pradera), un legendario que escapaba pasando junto al jugador, una optimización de navegación que dejaba sin camino a quien estaba junto al origen una prueba con error de sintaxis que dejaba a Godot trabado (de ahí `tools/run_tests.sh` con un vigilante que lo mata al pasar el límite, porque Godot ignora `SIGALRM`) y un perseguidor que, al pasar a pelear, ya no respetaba su área.

## Correcciones tras probar la 2.8 (`8247807`)
Fernando probó la 2.8 y pidió: vista despejada (Pokémon grandes tapaban), mira libre y botones claros para lanzar, botón para guardar o sacar al compañero, emboscadores sin parpadeo, barras de stamina y aire distintas, poder bucear y subir con animación de nado, y que el desmayo se viera (tirado en el suelo, recuperación visible) y le dejara **controlar a su Pokémon** para pelear y esquivar. También, que al debilitarse el compañero lo llevara al Centro Pokémon con aviso (antes solo reaparecía a los 30 s). Todo se hizo; además, catálogo de 97 megas con Mega Greninja.

## Fase 2.9 — Personaje y menú (en curso)
- **Bloque 1, personaje:** pantalla inicial con chico o chica, 5 personajes de cada uno (protagonistas de cada generación) con vista previa que camina y gira, nombre y dificultad (Fácil, Normal, Difícil: daño de salvajes, dinero perdido y tiempo de recuperación). Los textos usan el nombre elegido. Hojas descargadas de Spriters Resource y DeviantArt (las de DeviantArt desde su CDN, porque Chrome bloqueaba descargas repetidas del sitio) y convertidas con `tools/protagonist_sheets.py`.
- Siguientes bloques: ver el [plan](sistemas/menu_y_personaje.md).

## Mundo grande, pueblos, interiores, clima y montar (2026-10-10, `57ee187` y `e81a792`)
Pedido de Fernando: "el mundo es muy pequeño", con más biomas generados, estructuras ancestrales, alcantarillas, cuevas que llevan a otros lados, monturas, vuelo y bicicleta; y terminar todo lo pendiente de las fases anteriores.
- **Región de 4 × 4 km por semilla** (`RegionLayout`): 17 biomas por temperatura, humedad y altura; ríos que bajan al mar (o terminan en un lago si se atoran); lagos, oasis y lagos congelados; 13 asentamientos con edificios; caminos; ~80 lugares.
- **Construcción por zonas de 128 m** con hilos, dos niveles de detalle y faldas; navegación horneada por zona; mapa a 8 m/px en un hilo con caché. Arranque: 2.7 s (antes 5–6.5 s con un mundo 70 veces más chico).
- **Pueblos e interiores:** Centro Pokémon (cura, reaparición y autoguardado), tienda con MT, gimnasios con medallas, Liga con Calle Victoria, concursos, guardería, Safari, laboratorio (bicicleta, licencias, fósiles), tutores, casas; mazmorras generadas (cuevas por pares, alcantarillas, torre, mansión, central, laboratorio, minas, base del equipo criminal, distorsión de los portales, barco hundido).
- **Lugares:** ruinas con acertijo, grutas sin carga, ranchos, huertos, comerciantes, aguas termales y fuentes, ruinas flotantes, territorios Alfa, arrecife con corales, cascadas.
- **Clima por bioma y estaciones**, **eventos** (brotes, lluvia de estrellas, dominantes, Alfas).
- **Bicicleta, montura** (con escaladores) **y vuelo libre**, con licencias del profesor.
- **Opciones completas:** resolución, calidad, velocidad del texto, idioma, daltonismo y reasignar botones. Avisos en fila.
- **Pokédex regional definitiva** según el mundo generado.
- Problemas encontrados y corregidos: la navegación de las zonas con edificios salía vacía (cada lectura de geometría reemplazaba la anterior; ahora se combinan), los bordes de río dentro de lagos contaban como agua flotante, tierra adentro bajo el nivel del mar (ahora se comprime hacia arriba), un legendario volador que no subía al escapar de una cumbre (el arco ahora sube sobre el punto más alto) y el orden de inicialización de los servicios.

## Fase 2.7 — Habitantes con rutina (2026-10-10)
Habitantes por pueblo con casa, oficio y horario según la hora y el clima; hablan con saludo, oficio y comentario del clima; tienda y gimnasio con horario. El día/noche y el clima por bioma ya estaban hechos.
