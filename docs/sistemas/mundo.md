# Mundo abierto


> **Reemplazado** por el [mundo grande](mundo_grande.md) (2026-10-10): el mundo fijo de 480 m de este documento ya no existe; se conservan aquí el arte, el agua y el rendimiento de esa versión como referencia.

[← Índice](../README.md) · Código: `world/world_builder.gd`, `world/world_config.tres`, `world/biomes/*.tres`, `world/terrain/*.gdshader`

## Trazado (480 × 480 m, sin pantallas de carga)
| Zona | Dónde | Características |
|---|---|---|
| Pradera | Centro y este | Inicio en (0, 0) con 14 m planos; lago en (70, 70) |
| Bosque/humedal | Oeste | Denso y oscuro; pantano de 10 charcas en (−165, 95) |
| Montaña | Norte | Crestas; pisos de altura: tierra y pinos, roca desde 18 m y nieve desde 32 m |
| Costa | Sur | Playa que baja al mar |

- Fronteras deformadas con ruido; el suelo elige la textura de cada píxel con dither (sin degradados borrosos).
- Río (curva Catmull-Rom) de la montaña al mar: cruza el bosque, pasa por el lago y desemboca en la costa.
- Caminos de tierra (`WorldConfig.paths`) que unen el inicio con el lago, el bosque y el pantano, la montaña y la costa.

## Límite del mundo
- Fuera del área jugable (`_build_frontier`), una franja de 420 m: **cordillera infranqueable** al norte, este y oeste, que sube empinada desde el borde (55 a 125 m, con roca y nieve por altura, con el mismo shader del terreno), y **mar abierto** hasta el horizonte al sur de la costa. Es solo visual: los muros invisibles del borde siguen deteniendo al jugador, y en el mar una corriente lo regresa.

## Agua (nunca flota)
- Cada cuerpo de agua tiene **cauce y ribera**. El nivel sale del terreno más bajo a su alrededor (río encajado, nunca colgado), la superficie termina dentro de la ribera (borde enterrado) y tierra adentro nunca baja del nivel del mar.
- Los tramos del río dentro del lago o del mar no se dibujan (sin doble capa transparente).
- Shader `water_pixel.gdshader`: textura de B2W2 en coordenadas del mundo, desplazamiento por píxel y espuma en la orilla.
- La navegación excluye el agua profunda (obstrucciones proyectadas).
- Lo verifica `tests/test_world.tscn` (277 puntos de borde, el peor 5 cm bajo el terreno).

## Vegetación y props
- Por bioma (`BiomeConfig`): árboles y rocas con colisión, decoración con MultiMesh por zonas de 80 m (se dejan de dibujar a 170 m).
- Todo se apoya en la altura más baja de su base y se hunde un poco; árboles y rocas llevan una sombra de contacto (Decal) solo sobre el terreno.
- Coherencia: árboles sueltos en el borde del bosque, ribera viva (árboles, juncos, lavanda, flores), pantano con árboles muertos y bruma, y sin árboles arriba de la línea de roca.
- Hierba alta: parches por bioma con su tono; se mece con el viento y se aparta al paso de hasta 16 actores.

## Capas
- Colisión: 1 = terreno (la cámara choca), 2 = obstáculos (árboles, rocas, muros), 3 = actores (jugador y Pokémon no se empujan).
- Visual: 2 = sprites (las sombras de contacto no se proyectan sobre ellos).

## Rendimiento (M1, 1080p)
- Alturas calculadas una vez; construcción del mundo en ~6.5 s, tapada por la pantalla de carga (ver [interfaz.md](interfaz.md#pantalla-de-carga-2026-10-11)).
- Sombras del sol a 60 m con 2 divisiones; DOF de calidad baja.
- 60 s con 27 salvajes: 16.7 ms de promedio y 29 ms de peor cuadro.
