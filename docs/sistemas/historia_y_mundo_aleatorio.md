# Historia, caminos, tiempo y mundo aleatorio (plan)

[← Índice](../README.md) · Decidido con Fernando el 2026-10-09. Estado: **plan**.

## Inicio (✅ hecho: `world/starter/starter_ceremony.gd`)
- Tras elegir personaje, **5 huevos eclosionan a la vez** con básicos al azar. Eliges uno; los demás se van y no se vuelven a ver.
- Al elegido le lanzas la Pokéball (tutorial de apuntar y lanzar, captura segura). Es tu compañero de viaje.

## Mundo aleatorio con semilla
- Cada partida nueva genera su mapa a partir de una **semilla** guardada con la partida (se puede escribir una para repetir un mapa).
- Contenido: biomas, río, montañas, costa y todo lo del [catálogo](../catalogo_mundo.md): pueblos, ciudades, cabañas, rutas con distintos pavimentos, volcanes, cuevas, santuarios, lugares icónicos y actividades.
- **Límite del mundo:** mezcla de mar y montaña. Un lado es costa con mar abierto hasta el horizonte, donde una corriente te regresa ("La corriente es muy fuerte"). El resto es una cordillera infranqueable con montañas lejanas y niebla. Nunca se ve el borde.

## Personaje y elenco
- El personaje elegido define el aspecto y el elenco que lo acompaña, pero el **profesor, el rival y los personajes secundarios se eligen al azar** entre todos los de la serie en cada partida.
- La historia, el mapa y los caminos son aleatorios y **sin orden obligatorio**.

## Caminos (todos abiertos desde el inicio, en paralelo y en cualquier orden)
1. **Gimnasios y Campeón:** medallas, Alto Mando y Campeón. Como conflicto secundario se desmantela una organización criminal que quiere usar legendarios.
2. **Coordinador o Artista:** Concursos y Exhibiciones; 5 cintas para el Gran Festival (Súper Coordinador o Reina de Kalos).
3. **Investigador o Buscador de Mitos:** misterios antiguos, leyendas y completar la Pokédex.
4. **Academia y Tesoro:** Travesía de la Victoria, Senda Legendaria (Pokémon Dominantes e ingredientes) y Vía Stardust (bases del equipo rebelde).
5. **Líder de Gimnasio** y **Maestro Pokémon**. Completar varios caminos desbloquea el final especial de Maestro.
- El **Rotom Móvil** avisa de actividades pendientes y lleva el progreso de cada camino.

## Tiempo
- Reloj del juego con día y noche: **1 minuto real = 1 hora** (un día dura 24 minutos). De noche salen otros Pokémon. Dormir en una cama o tienda adelanta el tiempo.
- Las actividades dan plazos en días del juego (de 1 a 5).
- **Si no cumples a tiempo:**
  - pierdes la recompensa (puede volver más tarde);
  - baja tu reputación con ese grupo (menos misiones y precios más altos);
  - el mundo cambia (el equipo criminal toma una zona hasta que la liberes);
  - el rival se adelanta (gana la medalla o el descubrimiento y la siguiente prueba es más difícil);
  - salen noticias en el mundo: los NPC y el Rotom Móvil comentan lo que pasó y cambian los precios o los Pokémon de la zona.

## Recuperar vida del jugador
- **Descanso:** tras 10 s sin daño regenera poco a poco (ya hecho). Dormir en una tienda, una cama o el Centro Pokémon te cura por completo.
- **Comida y bayas:** las bayas recolectadas y la comida de las fogatas dan corazones.
- **Tu Pokémon te cura:** si conoce Deseo, Aromaterapia o similares, con un botón y tiempo de espera. Algunos salvajes amables (Chansey, Audino) curan si te acercas.
- **Lugares curativos:** aguas termales, fuentes y árboles de bayas.

## Agua
- Al entrar al agua profunda te hundes poco a poco; **mantener Espacio / ✕** te mantiene a flote o te hace subir.
- Si tu compañero es de tipo Agua, **surfeas sobre él**. Si no, nadas tú con una animación generada (en la superficie, de la cintura para arriba con brazadas; buceando, inclinado con burbujas) y él vuelve a su Pokéball.

### Cómo funciona la ceremonia (hecha)
- Al empezar una partida nueva (equipo vacío), 5 huevos aparecen en arco frente a la cámara, con manchas del color del tipo de su Pokémon. Se sacuden cada vez más fuerte (2.5 s) y eclosionan uno por uno con un destello.
- Salen 5 básicos distintos al azar (2 % de shiny cada uno), quietos y mirando al jugador, con su nombre encima. Mientras, no aparecen salvajes.
- Una tarjeta explica apuntar y lanzar. El primero que recibe una Pokéball se captura siempre y entra al equipo; queda como compañero donde cayó la ball, y los demás se van con una nube de hojas.
- Las pruebas apagan la ceremonia (`starter_ceremony = false` en `world/main.gd`) y usan un compañero al azar; la ceremonia tiene su propia prueba (`tests/test_starter`).
