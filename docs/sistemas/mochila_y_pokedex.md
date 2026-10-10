# Menú, mochila, Pokédex y guardado (hecho)

[← Índice](../README.md) · Plan original en [menú y personaje](menu_y_personaje.md). Código: `ui/menu/`, `core/items.gd`, `core/item_effects.gd`, `core/research.gd`, `core/dex_data.gd`, `core/save_system.gd`, `core/game_options.gd`.

## Menú (Esc / Options)
- Pausa el juego. Pestañas: **Equipo, Mochila, Pokédex, Ficha, Mapa, Controles, Opciones, Guardar**; se cambian con Q / E o L1 / R1.
- Arriba siempre está la **tira del equipo** (hasta 6): sprite de frente Gen 5, nombre, vida, tipos y ★ en el acompañante. Tocar uno abre su ficha.
- **Equipo:** ficha con sprite, número y categoría, tipos, temperamento, vida, estadísticas (base equilibrada `70 + (base − 70) × 0.5` + entrenamiento), Puntos de Entrenamiento por repartir con botones +1 (máx. 31 por estadística y 127 en total), vínculo, megas posibles, descripción y **Hacer acompañante** (cambia al compañero del mundo).
- **Ficha:** personaje, nombre, región, tiempo jugado, dinero, Pokédex, shinies, legendarios y dificultad.
- **Controles:** la misma lista de la Ayuda (teclado de Mac y PlayStation lado a lado).
- **Opciones** (se guardan en `user://options.cfg`): sensibilidad de mouse y stick, invertir Y, pantalla completa, volúmenes, densidad de Pokémon (baja 7, media 12, alta 18), mostrar la leyenda y reducir destellos. Pendiente: reasignar botones, resolución y calidad, velocidad del texto, idioma y daltonismo.
- **Guardar:** 3 ranuras manuales y autoguardado cada 5 minutos (ranura 0). En la pantalla de inicio aparece **Continuar** con cada ranura.

## Mochila (`creatures/data/items.json`)
- 14 bolsillos: Pokéballs, Curación, Comida y bayas, Señuelos y repelentes, Exploración, Recolección, Fabricación (recetas), Evolución, Megapiedras (una por mega, generadas del catálogo de megas), Equipables, Potenciadores, Tesoros, Objetos clave y Coleccionables. Íconos de 24 px del paquete de Showdown (`tools/copy_item_icons.py`); las megapiedras, la Piedra Llave y el Amuleto Iris se dibujan en pixel art.
- Mochila inicial: 20 Poké Ball, 5 Super Ball, 2 Ultra Ball, 3 Pociones, 5 Bayas Aranja, Repelente, 2 Bolas Humo, Mapa Pueblo y Cuerda Huida.
- Efectos (`ItemEffects`): elegir ball; pociones curan al compañero; bayas y comida dan corazones; repelente (sin apariciones cerca y los salvajes no te notan); Bola Humo y Poké Muñeco (los cercanos te pierden de vista); Miel (atrae hasta 2 Pokémon del lugar); Cuerda Huida; Velocidad X (×1.3), Directo (sigilo: te notan a la mitad de distancia), Huevo Suerte (shiny ×2); Caramelo Raro (+8 Puntos de Entrenamiento). Evolución, equipables y tesoros se usarán con los desbloqueos, el combate y las tiendas.
- **Fabricación:** recetas con bonguris, setas, piedras y bayas (Poké, Super y Ultra Balls, pociones, Bola Humo y Miel).

## Pokéballs
- Se cambia de ball con la **cruceta ↑ / ↓** o **R / F**. Abajo a la derecha: ícono, nombre, cantidad y efecto.
- Si no quedan del tipo elegido, no se lanza y sale un aviso (y cómo cambiar de ball).
- Multiplicadores (`CaptureRules.ball_multiplier`): Poké ×1, Super ×1.5, Ultra ×2, Master siempre; Veloz ×5 si no te notó; Ocaso ×3 de noche o en cuevas; Malla ×3.5 con Agua o Bicho; Buceo ×3.5 en el agua; Nido hasta ×3 con poco desarrollados; Peso ×2.5 con grandes; Acopio ×3.5 si ya lo capturaste; Sana deja la vida llena; Lujo (vínculo, con el combate).

## Pokédex
- Lista nacional de 1,025 (60 por página) con número regional, filtros por tipo, estado (vistos, capturados, sin ver, shiny, completados) y hábitat, y búsqueda por nombre o número.
- **Visto:** al acercarse a 22 m de un salvaje. **Capturado:** al capturarlo (también registra sexo y talla).
- Ficha: sprite (silueta si no lo viste), número, categoría, tipos, altura y peso, **grito** (PokeAPI), shiny si lo viste o capturaste; al capturarlo: descripción oficial en español, debilidades, estadísticas, cadena evolutiva, formas (sexos, shiny, megas), **comparar tamaño** con tu personaje y récords del más grande y el más pequeño.
- **Investigación** (`Research`): encuentros (1, 5, 10, 20), capturas (1, 2, 3, 5, 10), capturas por la espalda (1, 3, 5), verlo pelear (1, 3) y verlo debilitado (1, 3, 5); cada meta = 10 puntos, nivel = puntos / 10, completada con 100.
- **Mapa de hábitat:** visto = zona aproximada; capturado = áreas exactas; completada = además horario, clima y si es nómada.
- **Premios del profesor** por especies capturadas: 1 (Super Balls), 5 (Pociones), 10 (Ultra Balls), 25 (Caramelos Raros), 50 (Master Ball), 100 (Huevos Suerte) y 400 (Amuleto Iris, shiny ×3).
- Datos: `tools/build_dex_info.py` (categoría, descripción, altura, peso y sexo de PokeAPI; sprites de frente Gen 5; gritos en `art/cries/`).

## Pendiente
- Rueda de cambio rápido de acompañante (mantener Q / △), Caja (PC), Diario y misiones, Logros y estadísticas, Dinero y tiendas, guía inicial de cada pestaña y el número regional definitivo con el mundo grande.
