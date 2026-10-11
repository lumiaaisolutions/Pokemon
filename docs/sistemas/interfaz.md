# Interfaz: estilo Pokopia, menú, Pokédex, avisos, diálogo y HUD (hecho, 2026-10-10)

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

## Estilo claro (Pokopia) — reemplaza al azul marino (2026-10-10, segunda parte)
Fernando pidió el estilo de Pokémon Pokopia (sus imágenes, solo como referencia) en **toda** la interfaz.
- **Modo claro central** (`UiKit.light`): paneles crema, acentos rojos, botones tipo píldora. `UiKit.ink()` pasa los colores de texto pensados para fondo oscuro a tinta (blancos → oscuro; verdes y dorados claros → más oscuros), así todas las pestañas se convirtieron sin tocar cada color. Etiquetas sobre el mundo usan `UiKit.label_on_dark()`.
- **Tema**: campos blancos, desplegables crema, menús emergentes, deslizadores rojos e interruptores de píldora.
- **Menú (I / Start):** inicio con el juego visible a la izquierda y un **panel rojo** a la derecha (lente y luces, píldora con día, hora, dinero y tiempo) con la **cuadrícula de íconos** (`MenuIcon`, dibujados con vectores; halo amarillo, rebote y ▼ al enfocar). Al elegir, la sección abre a pantalla completa en un **marco rojo** con su título en píldora; pie con píldoras de botones. Esc vuelve al inicio; Q / E cambian de sección; I cierra.
- **Pokédex en cuadrícula** (8 por fila): capturados a color, vistos en silueta gris, no vistos solo con su número. Al enfocar, círculo amarillo y burbuja con el nombre; al abrir, su ficha completa con "Volver". Abajo: contador, búsqueda, tipo, estado, orden (número, nombre, tipo) y páginas.
- **Avisos en tarjetas** (`ui/notices/notice_cards.gd`): a la derecha bajo el reloj, máximo 3, con círculo de color e ícono por categoría (captura, objeto, dinero, misión, logro, combate, tu Pokémon, investigación, lugar, partida, aviso). La categoría sale del texto.
- **Caja de diálogo** (`ui/notices/dialog_box.gd`): abajo al centro, retrato y nombre en etiqueta roja, texto letra por letra, E avanza, opciones en píldoras (Retar / Adiós). Bloquea el movimiento mientras está abierta. Los avisos "Nombre: texto" se muestran aquí sin bloquear. La leyenda se oculta mientras hay diálogo.
- **Leyenda de botones:** pestaña "◂ Controles / Ocultar controles ▸" y **toque de H** para desplegar u ocultar (se recuerda en Opciones); **mantener H** abre la ayuda completa.
- **HUD claro:** paneles y píldoras crema con franja de color (una pasada automática pasa sus textos a tinta); los textos que flotan sobre el mundo siguen claros con contorno.

## Botones de acción en toda la interfaz (pedido de Fernando, 2026-10-10 ronda 3 · hecho)
Código: `ui/kit/ui_kit.gd` (`UiKit.action_button`, `UiKit._grow_on_focus`), `ui/kit/ui_icons.gd` (`UiIcons.action`), `ui/notices/dialog_box.gd`, `ui/camp/camp_menu_ui.gd`, `ui/camp/stargaze_overlay.gd`, `ui/menu/bag_tab.gd`, `ui/menu/menu_style.gd`.
- **Un solo estilo para todo:** `UiKit.action_button(texto, ícono, color, elegido, activo)` — ícono pixel + texto en píldora redonda, color propio por acción (con su borde más claro), sombra, y se agranda con un pequeño rebote y brilla (fondo más claro y sombra del color) al pasar el cursor o enfocarlo, con los sonidos `ui_select` / `ui_decide` de siempre.
- **Dónde se usa directamente** (ícono + color por acción): el **menú de la tienda de campaña** (`CampMenuUI`: Dormir, Cocinar, Recoger, Convivir, Mejorar campamento, Ver las estrellas, Nada — ver `docs/sistemas/jugador.md`), las **constelaciones** de Ver las estrellas, las **opciones de la caja de diálogo** (`DialogBox.open` ahora acepta `option_icons`/`option_colors`; si no se dan, usa un globo de diálogo genérico) y el **botón de acción de la Mochila** ("Comer", "Usar en tu compañero", "Lanzarás"… con el ícono del objeto y un color según lo que hace).
- **En el resto del juego** (menú, cocina, tienda, mochila…): `UiKit.side_button`, `UiKit.slant_button` y `MenuStyle.style_button` (la base que usan `MenuStyle.button`, `ui/camp/cooking_ui.gd`, `ui/menu/bag_tab.gd` y las pantallas de tienda) ganaron el mismo "se agranda y brilla al enfocar" (`UiKit._grow_on_focus`) sin tener que rehacer cada pantalla: ya tenían ícono, color y sonido propios donde correspondía.
- **Nuevos íconos** (`UiIcons.action`): dormir (luna), cocinar (olla), recoger/armar (tienda), convivir (corazón), mejorar (martillo), estrellas (la misma estrella de "Nueva partida") y nada/cancelar (cruz). El globo de diálogo genérico es el ícono "talk".

## Tablero de misiones (2026-10-10)
Código: `core/mission_board.gd` (junta las misiones), `ui/notices/mission_panel.gd` (pantalla).
- **En pantalla, a la izquierda** (debajo del panel de bienvenida si está): "MISIONES · [J] ver todas" y **3 tarjetas** con ícono, nombre y barra: las en curso con más avance.
- **J** (o mantener la cruceta ↓ medio segundo) abre el **tablero completo** en su propia capa, con marco rojo, por categoría: **Rotom** (actividades con plazo), **Megapiedras**, **Foto del día**, **Héroes** (rumores del día sin vencer) e **Investigación** (las 3 especies más cerca de completarse), con avance, detalle y premio. J o Esc lo cierran; pausa el juego.
- Acción nueva `missions` (J; reasignable en Opciones). Las regiones se agregarán como categoría cuando existan.
