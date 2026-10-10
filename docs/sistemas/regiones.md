# Viaje por regiones (diseño acordado con Fernando, 2026-10-10 · por hacer)

[← Índice](../README.md) · Estado: **diseñado, sin implementar**. Ver [plan de pulido](../plan_pulido_mundo.md).

## Idea
- **6 regiones:** la inicial y 5 más. Mismo formato (4 × 4 km, biomas, pueblos, caminos), pero cada una se **genera al azar con su semilla al desbloquearse**.
- **Nombres inventados** al azar, estilo Pokémon ("Región Aurelia").
- Tu equipo, Pokédex, mochila y dinero viajan contigo; se puede **volver** a cualquier región abierta.

## Completar una región (abre la siguiente)
- **8 medallas + Liga + la mitad (50 %) de las misiones del Rotom** de esa región.
- Al completarla, el **profesor te da el Boleto** (barco o avión) a la siguiente.

## Viaje
- **Barco o avión al azar por región** (decisión 2026-10-10): al generarse, cada región sortea si tiene **muelle con barco** o **aeropuerto con avión** en su pueblo inicial, y siempre se viaja así desde ella. Hablas con la capitana o la piloto, eliges una región abierta, ves una **animación corta** (barco en el mar o avión sobre las nubes) y llegas al pueblo inicial de la otra.

## Gimnasios y Liga
- **8 gimnasios por región** con líderes **al azar de Kanto a Teselia** (generaciones 1–5), **sin repetirse** entre regiones; cada uno con **su tipo** y equipo de ese tipo. Sprites originales de B2W2 (Torneo Mundial Pokémon, hoja "Overworld Entities").
  - **Catálogo confirmado (2026-10-10):** 29 líderes de la hoja de BW2 (Brock, Misty, Lt. Surge, Erika, Janine, Sabrina, Blaine, Falkner, Bugsy, Whitney, Morty, Jasmine, Pryce, Clair, Roxanne, Brawly, Wattson, Norman, Winona, Juan, Roark, Gardenia, Maylene, Crasher Wake, Byron, Elesa, Steven, Cynthia, Alder) + 15 más de la misma hoja (Clay A20, Skyla A21, Iris A23, Marlon A54, Brycen A22, Chuck A58, Flannery A60, Fantina A62, Wallace A63, Giovanni A56, Burgh A53, Drayden A59, Roxie A52, Cress A44, Chili A45) = **44**. Lámina de verificación en `~/Desktop/Pokemon_lideres_nuevos.png`.
  - **Los 4 restantes:** Koga, Blue, Volkner y Cilan (elección de Fernando). **Koga y Blue** salen de la hoja oficial de HGSS que ya está en el proyecto (`sprites/npc_src/prof_hgss_trainers.png`, celdas 37 y 49). **Cilan y Volkner** van **provisionales** (sprite parecido de BW2 + retrato oficial) porque Spriters Resource y Bulbagarden piden verificación de Cloudflare; **pendiente:** cambiarlos cuando Fernando pase la verificación en la Mac (hojas "Overworld Entities" de BW y "NPCs (Overworld)" de DP).
- **Reparto (2026-10-10):** por **afinidad con el bioma** del pueblo (Misty en costa o pueblo pesquero, Brock en el minero, Pryce en la nieve…); si no hay pueblo afín, al azar. El gimnasio usa el **tipo del líder**.
- **Reto del gimnasio (2026-10-10):** el **líder** está dentro con su sprite; antes, **2 entrenadores del gimnasio** de su tipo (opcionales). El líder usa su **equipo canónico**, de 3 a 6 Pokémon según la región, con la IA lista.
- **Liga por región (2026-10-10):** **4 del Alto Mando real** de Kanto a Teselia (18 en total; algunos repiten en otra región, nunca en la misma) y el **Campeón es un héroe no elegido** (Red, Lyra…) con su equipo icónico al máximo y mega. Los del Alto Mando sin sprite de DS van con uno provisional y su retrato oficial.
  - **Sprites del Alto Mando (aprobados 2026-10-10, lámina `~/Desktop/Pokemon_alto_mando.png`):** Lance, Will, Bruno y Karen (HGSS), Shauntal y Caitlin (BW2), Flint (Platino). **Provisionales** (clase de BW2 + retrato oficial): Lorelei, Agatha, Sidney, Phoebe, Glacia, Drake, Aaron, Bertha, Lucian, Grimsley y Marshal.
- Fuera de horario, los **líderes entrenan** cerca del pueblo o en un lugar de su tipo; ahí se les puede retar (amistoso).

## Dificultad
- **Sube por región:** salvajes más fuertes y evolucionados, líderes con equipos más grandes, megas desde la tercera región. Los héroes crecen contigo.

## Pokémon y legendarios
- **Pokédex regional al azar** por región (unas 200–300 especies según sus biomas): hay que viajar para completar la Pokédex.
- **Legendarios repartidos sin repetir** entre las 6 regiones (cada una con sus santuarios).

## Personajes
- **Profesor por región** (Oak, Elm, Birch, Rowan, Juniper…) con su **asistente**. Tu **rival** (sprite de Hugh) y los **héroes** viajan contigo a las regiones nuevas y siguen creciendo.
