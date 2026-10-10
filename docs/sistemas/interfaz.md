# Interfaz: kit visual, inicio, menú y HUD (hecho, 2026-10-10)

[← Índice](../README.md) · Código: `ui/kit/` (`ui_kit.gd`, `ui_icons.gd`, `radar_chart.gd`), `ui/character_select/`, `ui/menu/`, `ui/hud.gd`.

Pedido de Fernando: rediseñar toda la interfaz al estilo de Leyendas Z-A (sus imágenes de referencia), con íconos, más intuitiva y **responsive** (nada pegado a una esquina ni desfasado).

## Kit (UiKit)
- Fuente del sistema (Avenir Next, negrita 800 para títulos), fondo azul marino con degradado y franjas de luz, paneles redondeados translúcidos, encabezados blancos tipo etiqueta, botones en paralelogramo (`StyleBoxFlat.skew`), barras redondeadas y colores de vida.
- Botones laterales: al tener foco se vuelven blancos con franja menta. Suenan `ui_select` al mover el foco y `ui_decide` al elegir.
- **UiIcons:** íconos de 32 px dibujados en código (mochila, Pokédex, caja, trofeo, ficha, mando, engrane, guardar, jugar, estrella, salir) más íconos de objetos y de tipos.
- **RadarChart:** gráfica hexagonal de estadísticas con nombre y calificación (Normal, Bueno, Notable, Inmejorable).
- **Responsive:** el proyecto escala a 1920×1080 con `expand`; los contenidos usan márgenes proporcionales (`UiKit.centered_margin`) y anclas, no posiciones fijas.

## Pantalla de inicio y nueva partida
- **Título:** "POKÉMON · MUNDO ABIERTO" con 6 Pokémon que flotan y los botones Continuar (si hay partidas), Nueva partida, Opciones y Salir. Suena `bw2_title`.
- **Continuar:** una tarjeta por ranura (nombre y horas). **Opciones:** las mismas del menú del juego.
- **Nueva partida en 5 pasos** con chips de avance (✓ hechos, el actual en blanco): chico o chica → personaje (tarjetas que caminan) → nombre → dificultad (★ a ★★★ con su descripción) → resumen con semilla opcional. A la derecha, una tarjeta blanca con el personaje elegido que camina y gira.
- La dificultad se puede cambiar después en Menú → Opciones ("Dificultad (de esta partida)").

## Menú del juego (I o Start; la Mochila también con B)
Barra lateral "MENÚ" con íconos y chip de encabezado por sección. Pokémon (tarjetas, ficha, movimientos en rombo, gráfica, entrenamiento, megas y **evolución**), Mochila (bolsillos con ícono), Pokédex, **Cajas** (cuadrícula 6×5 con páginas y ficha), Rotom (actividades, **fotografía del día**, **megapiedras**, noticias), Logros, Dinero, Ficha, Mapa, Controles, Opciones y Guardar. Al abrirse oculta el HUD; Esc solo libera el mouse.

## HUD
Paneles del kit: tarjeta del compañero con **retrato**, nombre, vida y estado; panel de la Pokéball (franja roja); reloj y clima en píldora; nombre del lugar, avisos y ayuda de interacción en píldoras que se ajustan al texto (la de ayuda se oculta si está vacía); leyenda de botones según el contexto.
