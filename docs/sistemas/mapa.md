# Mapa y minimapa

[← Índice](../README.md) · Código: `ui/map/`

- **Imagen de la región** (`WorldMapData`): pixel art de **8 m por píxel** (512 × 512) con el color de cada uno de los 17 biomas, agua (mar, lagos, ríos y pantano), caminos, pueblos y sombreado del relieve. Se calcula en un hilo al iniciar y se guarda en `user://map_<semilla>_v2.png` (la siguiente vez carga al instante).
- **Niebla de exploración:** 8 m por píxel; se descubren 60 m alrededor del jugador cada 0.4 s. Se guarda comprimida en la partida. Las torres del reloj descubren 600 m.
- **Minimapa** (esquina superior derecha): 150 m de radio, gira con la cámara. Muestra al jugador (flecha), los salvajes (blancos; rojos si te persiguen; dorados si son shiny) y el punto seguro (pin azul: el último Centro Pokémon). Se oculta en interiores y hasta que la imagen está lista.
- **Mapa completo** (M o Select): la región con la niebla, los **pueblos** (rojo = ciudad, con nombre si ya los viste), los **lugares descubiertos** con su nombre, el punto seguro y el porcentaje explorado. Pausa el juego.
- La Pokédex usa la misma imagen para el mapa de hábitat.


## Mapa con zoom (2026-10-10)
- **Zoom** con la rueda (hacia el cursor) o zoom/cruceta; **arrastrar** o mover para desplazarse; hasta ×12.
- **Detalle por acercamiento:** pueblos siempre (icono de casa y nombre), lugares especiales desde ×1.8 (nombre desde ×2.5), Centro, tienda, gimnasio, laboratorio y concursos desde ×4.
- **Tarjeta** con nombre y qué hay al pasar el cursor.
- **Destino:** clic para marcarlo (bandera); en el minimapa se ve como **brújula** en el borde si está lejos (sin línea guía, como pidió Fernando). Clic derecho lo quita. Se guarda en `world_flags["waypoint"]`.
- Relieve suave y niebla con trama; marco rojo; el HUD se oculta con el mapa abierto.
