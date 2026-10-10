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

## Fase 2.8 — Mundo vivo (en curso)
Pedido tras probar la 2.5 (tirones, sprites rotos, aparición solo en hierba, demasiados legendarios):
1. **Sprites y tirones** (`8c0f14f`, `5b97ccd`): hojas de 64 px y lado derecho propio; caminos recalculados solo si el destino cambia; calentamiento de shaders. De 27 a 16.7 ms de promedio y de 854 a 29 ms de peor cuadro.
2. **Aparición, manadas, esconderse y legendarios** (`8c0f14f`): en cualquier lugar con cupo por zona, manadas de una línea evolutiva, escondite con efecto, legendarios en santuarios y cautelosos (pedido posterior de Fernando).
3. **Salto, vida, caídas, agua y desmayo** (`bff7a63`): pedido posterior estilo Minecraft.
4. **Coherencia de biomas** (`c6dee03`): nieve y roca por altura, caminos que conectan, borde del bosque, ribera viva y pantano.
5. **Peleas** (`0a228c3`) y **emboscadas** (`6d90c25`): rivalidades, aturdido y humo, ataques al jugador, defensa y guardia del compañero; Bicho que caen y aves en picada.
6. **Captura en el mundo**: apuntar y lanzar con física, fórmula oficial, sigilo y aturdido.
7. **Mapa**: minimapa y mapa completo con niebla de exploración.

Problemas encontrados y corregidos en el camino: un río colgado sobre laderas, charcas encimadas, manadas con especies de otro hábitat (Marill en la pradera), un legendario que escapaba pasando junto al jugador, una optimización de navegación que dejaba sin camino a quien estaba junto al origen y una prueba con error de sintaxis que dejaba a Godot trabado (de ahí `tools/run_tests.sh` con límite de tiempo).
