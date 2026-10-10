# Dirección de arte y assets

[← Índice](../README.md)

## Estilo
- **HD-2D con gráficos de Pokémon Negro 2/Blanco 2** (decisión final del 2026-10-09). Se descartaron el greybox low-poly y el estilo naturalista de Leyendas Arceus.
- Suelo 3D con texturas pixel art de B2W2; árboles, rocas, Pokémon y personajes como sprites billboard (eje Y).
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
