# Música y sonido (hecho, 2026-10-10)

[← Índice](../README.md) · Código: `core/audio_bus.gd` (autoload `AudioBus`), `world/music/music_director.gd`.

Decidido por Fernando: **banda sonora original de BW/BW2** y efectos de BW2. Los archivos son **solo locales** (`art/music/`, `art/sfx/`, en `.gitignore`); el juego funciona sin ellos (en silencio).

## AudioBus
- `play_music(key)`: dos reproductores con transición de 1,4 s y bucle. Volumen de Opciones (Música).
- `play_jingle(key)`: fanfarria corta; la música baja al 15 % mientras suena.
- `play_sfx(key, pitch)`: 6 canales de efectos (volumen de Opciones → Efectos).

## Qué suena (MusicDirector, cada 0,5 s, en este orden)
1. **Combate:** salvaje (`bw2_battle_wild2` o `bw1_battle_wild`), fuerte (Alfa o dominante), legendario, entrenador de camino, y en retos el gimnasio, la Liga o la base criminal.
2. **Interiores:** Centro y tienda, laboratorio, gimnasio, Liga, alcantarillas, cuevas, minas, torre, mansión, central, base criminal, distorsión, barco hundido, Calle Victoria. Las casas usan el tema del pueblo.
3. **Surf, bicicleta o vuelo.**
4. **Pueblos:** el inicial tiene `bw1_town_start`; los demás un tema fijo por tipo (ciudad, pueblo, aldea, cabañas) y bioma (tundra, playa, desierto).
5. **Lugares especiales** cercanos (ruinas, gruta, rancho, volcán, árbol gigante, santuario, safari, oasis, termas).
6. **Rutas por bioma y estación** (Ruta 19, 2, 6, 4, 22, 12, 23, Bosque Perdido…).

## Fanfarrias y efectos
| Momento | Sonido |
|---|---|
| Curar en el Centro / medalla | `bw1_heal` / `me_badge` |
| Objeto, regalo, tesoro | `me_item` |
| Captura | `caught` + `me_pokeget` |
| Victoria (salvaje / entrenador) | `bw1_victory_wild` / `bw1_victory_trainer` |
| Entrenador te ve | `spotted` + `bw1_spotted` |
| Evolución | `bw1_evolution` → `me_evolved` |
| Movimiento aprendido | `me_waza` |
| Misión cumplida | `me_mission_clear` |
| Lanzar, sacudida, escape de la ball | `ball_throw`, `ball_shake`, `ball_open` |
| Golpes por efectividad, desmayo | `hit_super`, `hit_normal`, `hit_weak`, `faint` |
| Puerta, bicicleta, salto, huida, guardar | `door`, `bicycle`, `jump`, `flee`, `save` |
| Interfaz | `ui_open`, `ui_close`, `ui_select`, `ui_decide`, `ui_cancel` |

## Fuentes
- Música: KHInsider (BW y BW2), convertida a MP3 de 128 kbps (96 pistas + 10 fanfarrias `me_*`). Fuente original en `sprites/music_src`.
- Efectos: The Sounds Resource (paquete de BW2, 235 MB descargado con permiso de Fernando), 27 WAV elegidos.
