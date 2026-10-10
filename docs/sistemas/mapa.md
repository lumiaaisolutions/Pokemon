# Mapa y minimapa

[← Índice](../README.md) · Código: `ui/map/`

- **Imagen del mundo** (`WorldMapData`): pixel art de 2 m por píxel generado al cargar, con colores por bioma (pradera, bosque, pantano, montaña, roca, nieve, playa), agua, caminos y sombreado del relieve (luz del noroeste).
- **Niebla de exploración:** 4 m por píxel; se descubren 40 m alrededor de Nate cada 0.4 s.
- **Minimapa** (esquina superior derecha): círculo de 60 m de radio que gira con la cámara ("adelante" hacia arriba). Muestra a Nate (flecha roja), los salvajes (puntos blancos; rojos si te persiguen o pelean; dorados si son shiny) y el inicio (pin azul).
- **Mapa completo** (M o Select): el mundo con la niebla, la cuadrícula, el inicio, la flecha de Nate y el porcentaje explorado. Pausa el juego; ocupa el 80 % del lado corto de la ventana.
- Pendiente para la capa 2.6: marcadores de pueblos, santuarios descubiertos y lugares icónicos. Para la Fase 5: guardar lo explorado.
