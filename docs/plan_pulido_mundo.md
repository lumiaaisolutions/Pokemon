# Plan de pulido del mundo (acordado con Fernando, 2026-10-10)

[← Índice](README.md) · Surgió de su prueba de las fases 3 a 5.6. **Regla nueva:** no asumir nada; toda decisión de diseño se pregunta con opciones y recomendación.

Orden elegido: **bugs → NPC → interiores → biomas** (el mapa entra con los NPC, porque muestra al profesor y a los héroes).

## 1. Bugs
**Hechos todos (2026-10-10).**
- La cámara entra en los edificios (modelos B2W2): revisar todos los modelos, cercas y lugares.
- Se atraviesan las cercas.
- El compañero dentro de un interior queda pegado al borde "como si quisiera pelear" sin nadie: limpiar su objetivo al entrar o salir.
- La fogata sigue de día y no se recoge (se rehace en el punto 2).
- Centro Pokémon y edificios blancos brillan de noche → **se oscurecen como el resto; ventanas, letreros y puerta con luz cálida**.
- Nombres de NPC que no corresponden al género.
- Los NPC cruzan el agua caminando → **nadan con animación** (medio cuerpo y ondas); los nadadores nadan por gusto.
- Rayo al sacar o guardar al Pokémon → **rojo con centro blanco, en zigzag como relámpago, de la mano de Nate hacia donde sale**; al sacarlo la ball se abre con destello; al guardarlo el Pokémon se vuelve rojo y el rayo lo absorbe.

## 2. NPC y personajes
**Hecho (2026-10-10):** clases de BW2 (39 aspectos, `art/npcs/`, `core/npc_looks.gd`, `tools/build_npc_sheets.py`); menos habitantes con lugar propio y espacio personal; conversación con caja de diálogo y opciones (Retar); ganas de pelear por oficio y día; retos al verte (viajeros y peleoneros); campamentos en pixel art con animación de armar y recoger; NPC que nadan; nombres por género.
**Acordado, por hacer:** profesor con sprite según su nombre, en el laboratorio de 8 a 19 h (de noche en su casa) y 1–2 días por semana de viaje a investigar a un lugar del mapa (si lo encuentras allá te da una misión o premio); **asistente** que dice dónde está (marcado en el mapa), recibe tus registros y entrega los premios de investigación; líderes con sprites de BW2 que entrenan fuera del gimnasio (reto amistoso); rival (Hugh) que te busca. Ver también [regiones](sistemas/regiones.md).

- **Aspecto:** sprites de las clases de BW2 según su oficio (Joven, Chica, Montañero, Pescador, Enfermera, Vendedor, Científico, Abuela…), no los héroes. Nombre según su género.
- **Menos y con oficio:** cada uno con rol y lugar (vendedor en su puesto, jardinero, pescador en el muelle, niño en el parque, guardia), rutina por hora y espacio personal (no se amontonan). Fuera del pueblo, solo viajeros y entrenadores.
- **Conversación:** se detiene y te mira; caja de diálogo abajo con retrato y nombre; E avanza. Al final, opciones según quién sea (Retar, Comprar/Vender, Misión, Adiós). Si te da algo: ícono del objeto y fanfarria. Luego sigue su rutina.
- **Ganas de pelear (cambia cada día, se mantiene ese día):** Karatekas, Entrenadores Guay y jóvenes 80 %; viajeros y pescadores 40 %; vendedores, abuelas y niños 10 %. Si hoy no quiere, solo habla; si lo vuelves a ver ese día, tiene las mismas opciones.
- **Quién reta al verte:** fuera del pueblo casi todos los que tienen Pokémon; en el pueblo solo los peleoneros; el resto habla si te acercas.
- **Premio de NPC del pueblo:** igual que los de camino (dinero y objeto, revancha diaria; equipo según su oficio).
- **Campamentos:** carpa y fogata con el estilo del mundo, solo fuera de pueblos; la arma al anochecer con animación y la recoge al amanecer (animación) y sigue su camino.
- **Profesor y personajes importantes (líderes, rival):** rutina (laboratorio de día, casa de noche) y viajes a lugares del mapa. Una **asistente/secretaria** en el laboratorio dice dónde está y se marca en el mapa. Los líderes entrenan fuera del gimnasio; el rival te busca para retarte.
- **Héroes no elegidos** (los otros 9 de los 10): existen como entrenadores **únicos, fuertes y competitivos**. Viajan por la región con su propia ruta y rutina; el Rotom avisa rumores de dónde se vieron. Equipo **fijo e icónico** (Red con Pikachu y Charizard…), 6 evolucionados, uno con mega, **IA lista** (cambia por tipo, esquiva, se cura) y **crecen progresivamente contigo** (según medallas y avance).
- **Entrenadores fuertes** además de los héroes: con buenos Pokémon y estrategia.
- **Avisos:** lo que dice un NPC en la caja de diálogo; el resto en **tarjetas con ícono y color por categoría** (objeto, captura, misión, clima, logro) que entran por la derecha y se apilan.

## 3. Mapa
**Hecho (2026-10-10):** zoom, arrastre, detalle por acercamiento, tarjeta al pasar el cursor y destino en el minimapa como brújula.
- **Ilustrado con zoom:** rueda o gatillos para acercar (región completa a calles), arrastrar para moverse; terreno por bioma, caminos y ríos; íconos grandes por tipo (pueblos, Centro, tienda, gimnasio, cuevas, ruinas, lugares, profesor y héroes vistos, misiones). Tarjeta al pasar el cursor. La niebla de lo no explorado se mantiene.
- **Marcar destino:** marca en la brújula y el minimapa, **sin línea de guía en el camino**.

## 4. Interiores
- **Modelos originales de B2W2** (The Models Resource): Centro con mostrador y enfermera, tienda con estantes, casas con muebles, laboratorio con máquinas, gimnasios. Todo lugar donde se entre debe tener diseño.
- Descargas: se pide permiso **una vez por lote** con la lista y el tamaño aproximado.

## 5. Biomas
- **Kit por bioma + puntos de interés.** Ejemplos: pantano (charcos, juncos, nenúfares, árboles muertos, troncos, neblina baja); pantano tóxico (charcos morados que burbujean, hongos venenosos, árboles secos, gas); pradera (flores en grupos, rocas, arbustos, cercas viejas, letreros). Puntos de interés cada cierta distancia: campamento abandonado, pozo, ruinas pequeñas, árbol grande con bayas, cueva chica, mirador.

## 6. Interfaz estilo Pokopia (pedido 2026-10-10, sus imágenes solo como referencia)
**Hecho (2026-10-10):** menú con panel rojo e íconos vectoriales, secciones con marco rojo, Pokédex en cuadrícula, estilo claro en HUD, combate, inicio, diálogo y avisos en tarjetas; pestaña para la leyenda (toque de H).
- **Menú:** el juego sigue visible a la izquierda (con minimapa); a la derecha un **panel rojo redondeado** con bolitas de color arriba. Dentro, tarjeta clara con **cuadrícula de íconos grandes y coloridos** (Pokémon, Mochila, Pokédex, Cajas, Rotom, Foto, Mapa, Logros, Opciones, Guardar). Al elegir, la sección se abre en pantalla completa con el mismo marco rojo.
- **Íconos dibujados estilo Pokopia** (pixel art de alta resolución, redondeados), con rebote y halo amarillo al enfocarlos.
- **Pokédex:** cuadrícula de 8 por fila; capturados con sprite a color, vistos en silueta gris; **los no vistos no aparecen** (hueco con su número). Al enfocar, burbuja con el nombre y círculo amarillo. Abajo: filtro, orden y contador. Al abrir uno, su ficha.
- **Un solo estilo en todo el juego** (HUD, combate, inicio, diálogos): paneles claros redondeados, acentos rojos, botones tipo píldora con el glifo del botón. Reemplaza el azul marino.

## 7. Pueblos con identidad (acordado 2026-10-10)
- **Tema por pueblo** según bioma y tamaño (pesquero, minero, agrícola, turístico, científico, histórico, deportivo…). El tema decide: estilo de casas, un **monumento o edificio icónico** (faro, molino, estatua, fuente, mercado, puerto, torre), plaza con decoración propia, puestos, colores y NPC de oficios acordes.

## Bugs extra reportados
- Fruto visible distinto al objeto recogido (árbol de bonguri). **Hecho.**
- Agua de charcas que flota en pendiente. **Hecho** (nivel por la orilla más baja).
- Faltan caras traseras en modelos de B2W2. **Hecho** (núcleo sólido).

## 8. Tablero de misiones (acordado 2026-10-10)
- **A la izquierda**, bajo las instrucciones de bienvenida: 3 tarjetas pequeñas con ícono, nombre y barra de avance (en curso o con más avance).
- **J** (o mantener cruceta ↓) abre el **tablero completo**: todas las misiones por categoría (Rotom, megapiedras, foto, entrenadores, investigación, regiones) con objetivos y premios.

## 9. Viaje por regiones (acordado 2026-10-10)
Ver [regiones](sistemas/regiones.md): 6 regiones generadas al desbloquearse, 8 líderes al azar de Kanto a Teselia por región, Liga por región, completar con 8 medallas + Liga + 50 % de misiones, viaje en barco o avión, dificultad que sube, Pokédex regional y legendarios repartidos, profesor por región.

## Orden de trabajo actual
1. ~~Profesor, asistente y rival~~ (**hecho**, ver [personajes](sistemas/personajes_importantes.md); los líderes por tipo van con las regiones) → 2. ~~Héroes no elegidos~~ (**hecho**, ver [héroes](sistemas/heroes.md)) → 3. ~~Tablero de misiones~~ (**hecho**) → 4. ~~Interiores~~ (**hecho**, ver [edificios](sistemas/edificios_b2w2.md)) → 5. ~~Biomas~~ (**hecho**: kit, pasto, flores y puntos de interés) → 6. ~~Pueblos con identidad~~ (**hecho**) → 7. ~~Regiones~~ (**hecho**, ver [regiones](sistemas/regiones.md); pendiente: sprites definitivos de Cilan y Volkner).

### Nota sobre los líderes (2026-10-10)
En la hoja de BW2 reconozco con certeza a Brock, Misty, Lt. Surge, Whitney, Brawly, Roark, Crasher Wake, Clair, Flint, Steven y a los de BW2 (Clay, Skyla, Marlon, Iris, Elesa, Lenora, Cheren). El resto se nombrará con un **catálogo que Fernando confirme** antes de las regiones.

## Pedidos nuevos tras las regiones (2026-10-10, en este orden)
1. ~~Destello de los shiny~~ (**hecho**) → [salvajes](sistemas/pokemon_salvajes.md).
2. ~~Salvajes comunes que se repiten y raros escasos~~ (**hecho**) → [salvajes](sistemas/pokemon_salvajes.md).
3. Voladores y Bicho en árboles: tamaño, Bicho en el suelo, desfase desde arriba → [salvajes](sistemas/pokemon_salvajes.md).
4. ~~Viaje entre regiones en 3D estilo BW2~~ (**hecho**) → [regiones](sistemas/regiones.md).
5. Animaciones de ataques (25 familias) → [animaciones de ataques](sistemas/animaciones_ataques.md).
6. Campamento, comida y hambre → [jugador](sistemas/jugador.md).
