# Edificios y decoración con modelos de B2W2 (hecho, 2026-10-10)

[← Índice](../README.md) · Código: `world/region/building_models.gd`, `world/region/structures.gd`. Modelos: `art/models/b2w2/<nombre>/` (Collada, 52 carpetas).

Pedido de Fernando: los edificios no respetaban el estilo del mundo, las casas estaban "en medio de la nada" y faltaba decoración.

- **Modelos 3D originales de B2W2** (The Models Resource, descargados con su permiso). Escala 0,08 m por unidad, texturas con filtro nearest y recorte alfa; las sombras "kage" se dibujan con alfa.
- Tabla `BuildingModels.MODELS`: Centro Pokémon, tiendas, 13 casas, cabañas, laboratorios, sala de concursos, 4 gimnasios (se excluyeron los de Castelia y Nimbasa por tamaño), torres y lugares (Torre Celeste, mansión, faro, ruinas, santuario, invernadero).
- Cada edificio: cimiento, colisionador del 90 % del tamaño, puerta al frente, letrero, punto de entrada. **Se entra caminando hacia la puerta** (o con E).
- **Decoración:** flores junto a la puerta, arbustos en las esquinas, farol que se enciende de 18:30 a 6:30, cercas y buzón en las casas.
- **Caminos** de cada puerta a la plaza (pintados en el terreno).
- **Recolección con contexto:** las bayas salen en arbustos y árboles; las setas junto a un árbol; las piedras en rocas; las conchas junto al agua. Al recoger se oculta el fruto, no la planta.


## Interiores con modelos de B2W2 (2026-10-10)
Pedido de Fernando: "todo debe tener diseño por dentro". Lote 2 de descargas (aprobado): 24 interiores de The Models Resource en `art/models/b2w2_int/`.
- **Arreglo para Godot** (`tools/fix_dae.py`): los .dae traen varias `instance_geometry` por nodo (Godot solo importa una: se perdía casi todo) y rutas de textura codificadas (`Pok%c3%a9mon%20Center…`). El script separa las instancias en nodos hijos y renombra texturas y modelo a nombres simples (`t_0001.png`, `model.dae`). Las 3 casas de Nuvema se descartaron (esqueleto que Godot no importa).
- **Qué usa cada edificio** (`Interiors.INTERIOR_MODELS`): Centro → Centro Pokémon; tienda → centro comercial; laboratorio → lab de la Prof. Encina o de Fennel; casas → Floccesy, Humilau, Mistralton, Accumula; cabaña → casa de Hugh; gimnasios → Aspertia, Castelia, Mistralton, Icirrus, Humilau, Nacrene; Liga → salas del Alto Mando; concursos → Escuela de Entrenadores; guardería → Guardería.
- El modelo se centra y apoya en y = 0; su geometría es **sólida** (paredes y muebles, en la capa de obstáculos, así la cámara no choca) y hay un **piso** invisible. Los personajes y puntos (enfermera, PC, tienda, cama, profesor, líder…) se reubican según el tamaño real. Las mazmorras siguen con bloques.

### Arreglos tras la prueba de Fernando (2026-10-10, tarde)
- **Caída al vacío** en una casa: en varios modelos la caja que los rodea es mayor que el cuarto (paredes externas y zonas negras), y la entrada quedaba fuera del piso. Ahora la sala se ubica sobre el **piso real** (la superficie horizontal con más área, `Interiors._floor_rect`), con **paredes invisibles** en todo el contorno, **salida marcada** (tapete rojo y "▼ SALIDA"; se sale con E o caminando hacia ella) y **red de seguridad**: si tú o tu Pokémon caen 4 m bajo la entrada, vuelven a ella. Probado caminando hacia las orillas de los 19 interiores.
- **Parpadeo** en bordes: el cimiento de los edificios sobresalía 5 cm sobre la base del modelo (ahora queda 2 cm abajo) y las sombras pintadas ("kage") estaban en el plano del piso (ahora se suben un poco y se dibujan después).
- El laboratorio de la Prof. Encina se quitó (trae esqueleto que Godot no importa), como las casas de Nuvema.
- **Lote 3 (casas):** casa de Alder, Black City, Ruta 5, Ruta 13 y casa del jugador (las 5 cargan; Lentimas se descartó por su esqueleto). Las casas ahora tienen 9 variantes.
