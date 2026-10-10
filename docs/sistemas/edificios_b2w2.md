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
