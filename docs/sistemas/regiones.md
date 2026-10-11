# Viaje por regiones (diseño acordado con Fernando, 2026-10-10)

[← Índice](../README.md) · Estado: **implementado (2026-10-10)**; pendiente: sprites definitivos de Cilan y Volkner (ver abajo). Ver [plan de pulido](../plan_pulido_mundo.md).

## Idea
- **6 regiones:** la inicial y 5 más. Mismo formato (4 × 4 km, biomas, pueblos, caminos), pero cada una se **genera al azar con su semilla al desbloquearse**.
- **Nombres inventados** al azar, estilo Pokémon ("Región Aurelia").
- Tu equipo, Pokédex, mochila y dinero viajan contigo; se puede **volver** a cualquier región abierta.

## Completar una región (abre la siguiente)
- **8 medallas + Liga + la mitad (50 %) de las misiones del Rotom** de esa región. Misiones = avance de los otros 3 caminos del Rotom (Concursos 5 + Investigación 10 + Academia 6 = 21): hacen falta **11** (decisión 2026-10-10; los gimnasios ya cuentan con las medallas).
- Al completarla, el **profesor te da el Boleto** (barco o avión) a la siguiente.

## Viaje
- **Barco o avión al azar por región** (decisión 2026-10-10): al generarse, cada región sortea si tiene **muelle con barco** o **aeropuerto con avión** en su pueblo inicial, y siempre se viaja así desde ella. Es una **taquilla en el pueblo inicial** (decisión 2026-10-10: el agua queda a 40–420 m según la región) con el **capitán** (barco) o el **piloto** (avión); el barco o el avión se ven solo en la animación. Eliges una región abierta, ves una **animación corta** (barco en el mar o avión sobre las nubes) y llegas al pueblo inicial de la otra.
  - **Animación en 3D — hecha** (`ui/travel/travel_scene.gd`, 6 s: Ferry con estela y balanceo entre islas, o el avión de la región entre nubes pixel art sobre el mar; cámara que gira alrededor; fundido y nombre del destino) (pedido de Fernando, 2026-10-10: "en 3D con el estilo que ya conoces, que no se vea como lienzo, estilo BW2"): escena 3D con el agua del juego, islas y nubes, y cámara que sigue al vehículo.
  - **Modelos originales de B2W2** (lote aprobado y descargado el 2026-10-10, The Models Resource, `art/models/b2w2_travel/`): Royal Unova, Ferry, Avión 1 (pasajeros), Avión 2 (carga de Mistralton), Aeropuerto de Mistralton y Torre de control.
  - **Elección de Fernando:** barco = **Ferry**; avión = **al azar entre los dos** (por región); taquilla = **Aeropuerto de Mistralton con la Torre** en las regiones con avión, y en las de barco la caseta con el Ferry amarrado detrás en miniatura.

## Gimnasios y Liga
- **8 gimnasios por región** con líderes **al azar de Kanto a Teselia** (generaciones 1–5), **sin repetirse** entre regiones; cada uno con **su tipo** y equipo de ese tipo. Sprites originales de B2W2 (Torneo Mundial Pokémon, hoja "Overworld Entities").
  - **Catálogo confirmado (2026-10-10):** 29 líderes de la hoja de BW2 (Brock, Misty, Lt. Surge, Erika, Janine, Sabrina, Blaine, Falkner, Bugsy, Whitney, Morty, Jasmine, Pryce, Clair, Roxanne, Brawly, Wattson, Norman, Winona, Juan, Roark, Gardenia, Maylene, Crasher Wake, Byron, Elesa, Steven, Cynthia, Alder) + 15 más de la misma hoja (Clay A20, Skyla A21, Iris A23, Marlon A54, Brycen A22, Chuck A58, Flannery A60, Fantina A62, Wallace A63, Giovanni A56, Burgh A53, Drayden A59, Roxie A52, Cress A44, Chili A45) = **44**. Lámina de verificación en `~/Desktop/Pokemon_lideres_nuevos.png`.
  - **Los 4 restantes:** Koga, Blue, Volkner y Cilan (elección de Fernando). **Koga y Blue** salen de la hoja oficial de HGSS que ya está en el proyecto (`sprites/npc_src/prof_hgss_trainers.png`, celdas 37 y 49). **Cilan y Volkner** van **provisionales** (sprite parecido de BW2 + retrato oficial) porque Spriters Resource y Bulbagarden piden verificación de Cloudflare; **pendiente:** cambiarlos cuando Fernando pase la verificación en la Mac (hojas "Overworld Entities" de BW y "NPCs (Overworld)" de DP).
- **Reparto (2026-10-10):** por **afinidad con el bioma** del pueblo (Misty en costa o pueblo pesquero, Brock en el minero, Pryce en la nieve…); si no hay pueblo afín, al azar. El gimnasio usa el **tipo del líder**.
- **Reto del gimnasio (2026-10-10):** el **líder** está dentro con su sprite; antes, **2 entrenadores del gimnasio** de su tipo (opcionales). El líder usa su **equipo canónico**, de 3 a 6 Pokémon según la región, con la IA lista.
- **Liga por región (2026-10-10):** **4 del Alto Mando real** de Kanto a Teselia (18 en total; algunos repiten en otra región, nunca en la misma) y el **Campeón es un héroe no elegido** (Red, Lyra…) con su equipo icónico al máximo y mega. Los del Alto Mando sin sprite de DS van con uno provisional y su retrato oficial.
  - **Sprites del Alto Mando (aprobados 2026-10-10, lámina `~/Desktop/Pokemon_alto_mando.png`):** Lance, Will, Bruno y Karen (HGSS), Shauntal y Caitlin (BW2), Flint (Platino). **Provisionales** (clase de BW2 + retrato oficial): Lorelei, Agatha, Sidney, Phoebe, Glacia, Drake, Aaron, Bertha, Lucian, Grimsley y Marshal.
- **Vida de los líderes (pedido de Fernando, 2026-10-10: "que no se queden estáticos, similar al profesor"):**
  - Rutina: **gimnasio de 9 a 15 h**; de **15 a 20 h entrenan** en un lugar de su tipo cerca del pueblo (agua, rocas, pasto…); **de noche en su casa**; **1 día por semana viajan** a otro pueblo o lugar del mapa.
  - **Caminan** por el pueblo entre el gimnasio, su lugar de entrenamiento y su casa (con su sprite), como los habitantes.
  - **La medalla solo se gana en el gimnasio.** Si no está, un entrenador del gimnasio dice dónde anda y se marca en el mapa. Fuera del gimnasio se le puede retar a un **combate amistoso** (dinero, sin medalla, uno por día).

## Dificultad
- **Sube por región:** salvajes más fuertes y evolucionados, líderes con equipos más grandes, megas desde la tercera región. Los héroes crecen contigo.

## Pokémon y legendarios
- **Pokédex regional al azar** por región (unas 200–300 especies según sus biomas): hay que viajar para completar la Pokédex.
- **Legendarios repartidos sin repetir** entre las 6 regiones (cada una con sus santuarios).

## Personajes
- **Profesor por región** (Oak, Elm, Birch, Rowan, Juniper…) con su **asistente**. Tu **rival** (sprite de Hugh) y los **héroes** viajan contigo a las regiones nuevas y siguen creciendo.

## Implementación (2026-10-10)
- **`core/regions.gd`** (`Regions`): crea las 6 regiones al cargar el mundo (`ensure`, semilla de la partida): nombre, semilla, barco o avión, 8 líderes, 4 del Alto Mando (los menos usados primero), Campeón (héroe no elegido), profesor, líneas evolutivas de su Pokédex (cada línea en al menos una región + otras hasta ~250 especies) y legendarios (repartidos sin repetir). `switch_to` guarda lo de la región actual (banderas, actividades, zonas, avance) y carga lo de la otra; `GLOBAL_FLAGS` (licencias, bicicleta, guardería, rival) viajan contigo. `progress()` y `give_ticket()` para el Boleto. Se guarda con la partida (`regions`, `region_index`); las partidas viejas crean sus regiones al cargar.
- **`core/leaders.gd`** (`Leaders`): catálogo de 48 líderes y 18 del Alto Mando (tipo, equipo canónico de débil a fuerte, afinidad con el tema del pueblo, aspecto provisional). El equipo del líder crece por región (3, 4, 4, 5, 6, 6) y con tus medallas; megas desde la tercera región. Retratos en `art/portraits/<id>.png`.
- **Sprites:** `tools/build_leader_sheets.py` → `art/npcs/lider_<id>.png` y `alto_<id>.png` (BW2, HGSS y Platino; los cuadros que faltan en la fuente se rellenan con el frente o el espejo).
- **8 gimnasios por región:** ciudades y pueblos (y aldeas si faltan), `region_layout.gd`. `Structures.leader_of` asigna los líderes por afinidad (`Regions.assign_leaders`); el gimnasio usa el tipo del líder (techo y letrero).
- **Gimnasio:** líder al fondo (solo de 9 a 15 h), 2 entrenadores opcionales y un **guía** que dice dónde anda el líder y lo marca en el mapa. Combate de verdad (`BattleManager.start_trainer`) con IA lista.
- **Vida de los líderes:** `world/npc/gym_leaders.gd` (`GymLeaders`): rutina, trayecto por la plaza, lugar de entrenamiento según su tipo con su Pokémon estrella dando saltitos, viaje semanal, combate amistoso diario, marcas del mapa. Si la hora salta y el líder está lejos de tu vista, aparece en su lugar.
- **Liga:** `town_services.gd` (`league_talk`, `league_challenge`): los 4 del Alto Mando en semicírculo y el Campeón al fondo; en orden, y si pierdes o sales, vuelves a empezar.
- **Boleto:** al hablar con el profesor (`_region_ticket`); el tablero de misiones tiene la categoría **Regiones** con el avance.
- **Viaje:** `world/region/travel_terminal.gd` (taquilla con capitán o piloto en el pueblo inicial) y `ui/travel/travel_overlay.gd` (animación de barco o avión); la escena se recarga en la región nueva, con aviso de bienvenida la primera vez.
- **Dificultad:** los salvajes suben de etapa con 12 % más de probabilidad por región y las manadas traen líder evolucionado más seguido (`wild_spawner.gd`).
- **Héroes y rival** crecen con las medallas de todas las regiones (`Regions.total_badges`).
- **Prueba:** `tests/test_regions.gd` (en `tools/run_tests.sh`).
