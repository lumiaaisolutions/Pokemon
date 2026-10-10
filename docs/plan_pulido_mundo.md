# Plan de pulido del mundo (acordado con Fernando, 2026-10-10)

[← Índice](README.md) · Surgió de su prueba de las fases 3 a 5.6. **Regla nueva:** no asumir nada; toda decisión de diseño se pregunta con opciones y recomendación.

Orden elegido: **bugs → NPC → interiores → biomas** (el mapa entra con los NPC, porque muestra al profesor y a los héroes).

## 1. Bugs
- La cámara entra en los edificios (modelos B2W2): revisar todos los modelos, cercas y lugares.
- Se atraviesan las cercas.
- El compañero dentro de un interior queda pegado al borde "como si quisiera pelear" sin nadie: limpiar su objetivo al entrar o salir.
- La fogata sigue de día y no se recoge (se rehace en el punto 2).
- Centro Pokémon y edificios blancos brillan de noche → **se oscurecen como el resto; ventanas, letreros y puerta con luz cálida**.
- Nombres de NPC que no corresponden al género.
- Los NPC cruzan el agua caminando → **nadan con animación** (medio cuerpo y ondas); los nadadores nadan por gusto.
- Rayo al sacar o guardar al Pokémon → **rojo con centro blanco, en zigzag como relámpago, de la mano de Nate hacia donde sale**; al sacarlo la ball se abre con destello; al guardarlo el Pokémon se vuelve rojo y el rayo lo absorbe.

## 2. NPC y personajes
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
- **Ilustrado con zoom:** rueda o gatillos para acercar (región completa a calles), arrastrar para moverse; terreno por bioma, caminos y ríos; íconos grandes por tipo (pueblos, Centro, tienda, gimnasio, cuevas, ruinas, lugares, profesor y héroes vistos, misiones). Tarjeta al pasar el cursor. La niebla de lo no explorado se mantiene.
- **Marcar destino:** marca en la brújula y el minimapa, **sin línea de guía en el camino**.

## 4. Interiores
- **Modelos originales de B2W2** (The Models Resource): Centro con mostrador y enfermera, tienda con estantes, casas con muebles, laboratorio con máquinas, gimnasios. Todo lugar donde se entre debe tener diseño.
- Descargas: se pide permiso **una vez por lote** con la lista y el tamaño aproximado.

## 5. Biomas
- **Kit por bioma + puntos de interés.** Ejemplos: pantano (charcos, juncos, nenúfares, árboles muertos, troncos, neblina baja); pantano tóxico (charcos morados que burbujean, hongos venenosos, árboles secos, gas); pradera (flores en grupos, rocas, arbustos, cercas viejas, letreros). Puntos de interés cada cierta distancia: campamento abandonado, pozo, ruinas pequeñas, árbol grande con bayas, cueva chica, mirador.

## 6. Interfaz estilo Pokopia (pedido 2026-10-10, sus imágenes solo como referencia)
- **Menú:** el juego sigue visible a la izquierda (con minimapa); a la derecha un **panel rojo redondeado** con bolitas de color arriba. Dentro, tarjeta clara con **cuadrícula de íconos grandes y coloridos** (Pokémon, Mochila, Pokédex, Cajas, Rotom, Foto, Mapa, Logros, Opciones, Guardar). Al elegir, la sección se abre en pantalla completa con el mismo marco rojo.
- **Íconos dibujados estilo Pokopia** (pixel art de alta resolución, redondeados), con rebote y halo amarillo al enfocarlos.
- **Pokédex:** cuadrícula de 8 por fila; capturados con sprite a color, vistos en silueta gris; **los no vistos no aparecen** (hueco con su número). Al enfocar, burbuja con el nombre y círculo amarillo. Abajo: filtro, orden y contador. Al abrir uno, su ficha.
- **Un solo estilo en todo el juego** (HUD, combate, inicio, diálogos): paneles claros redondeados, acentos rojos, botones tipo píldora con el glifo del botón. Reemplaza el azul marino.

## 7. Pueblos con identidad (pedido 2026-10-10)
- Cada pueblo y ciudad debe tener identidad propia, más detalles y decoración (se ven vacíos e iguales). **Por preguntar** antes de hacerlo: temas por pueblo, monumentos, plazas, mercados, etc.

## Bugs extra reportados
- Fruto visible distinto al objeto recogido (árbol de bonguri). **Hecho.**
- Agua de charcas que flota en pendiente. **Hecho** (nivel por la orilla más baja).
- Faltan caras traseras en modelos de B2W2. **Hecho** (núcleo sólido).

## 8. Tablero de misiones (pedido 2026-10-10)
- En la pantalla principal, un tablero con **solo 3 misiones**: las que estén en curso o con más avance.
- Un botón abre el **tablero completo**: misiones, objetivos y avances. **Por preguntar** al llegar a la interfaz: posición, tecla y qué cuenta como misión (actividades del Rotom, megapiedras, foto del día, entrenadores, investigación).
