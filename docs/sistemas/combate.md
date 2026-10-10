# Combate en arena, captura en combate y megaevolución (Fases 3 y 4, hechas)

[← Índice](../README.md) · Código: `world/battle/` (`battle_manager.gd`, `battle_ui.gd`, `mega_effect.gd`), `world/capture/throw_aim.gd`, `world/player/player.gd`. Prueba: `tests/test_battle.tscn`.

Decidido por Fernando (2026-10-10): **arena en el lugar**, inicio al tocarse o al atacarse, cambio de Pokémon con espera y objetos con la Mochila (pausa).

## Inicio
- Empieza cuando tu compañero ataca a un salvaje, un salvaje te ataca a ti o a él, o te toca (`main._on_wild_contact`). `BattleManager.can_start` lo impide si: hay un combate activo, el salvaje es legendario, de la ceremonia, de un reto de gimnasio, está aturdido o te ignora tras una huida (`fled_until`), o si tu Pokémon no está fuera o vas montado, nadando o volando.
- Se crea un **anillo de 15 m** (`ARENA_RADIUS`) entre los dos. El mundo se pausa: Spawner, legendarios, emboscadas, eventos, habitantes, recolección y los demás salvajes (`_freeze_world`, que solo reactiva lo que él detuvo).
- La cámara pasa detrás de tu Pokémon y lo controlas directo (movimiento, esquiva, fijar objetivo y 4 movimientos). El jugador queda en el borde.
- Los salvajes avisan sus ataques con un **anillo rojo en el suelo** durante la preparación (`PokemonActor._telegraph`).
- `BattleManager.enabled` (estático) se apaga en las pruebas viejas, que revisan las peleas en el mundo.

## Dentro de la arena
| Acción | Teclado / mando |
|---|---|
| Mover y esquivar a tu Pokémon | WASD · Espacio / B |
| Fijar objetivo | Tab / R3 |
| 4 movimientos | 1–4 / X, Y, B, A |
| Megaevolucionar | G / cruceta ↑ |
| Cambiar de Pokémon (2 s de espera) | Mantener Q / Y (rueda) |
| Mochila (pausa) | B (teclado) o el menú |
| Apuntar Pokéball (pasa el control a Nate) | Clic derecho / LT |
| Huir | Salir del círculo |

- **Cambio:** `switch_to(index)`, con espera `SWITCH_COOLDOWN`; si tu Pokémon cae, sale el siguiente sano (`on_companion_fainted`); si no queda ninguno, pierdes.
- **Huir:** sacar a tu Pokémon del círculo. El salvaje te ignora un rato (`FLEE_IGNORE`). Suena `flee`.

## Recompensas al vencer (sin experiencia)
Elegidas por Fernando: Puntos de Entrenamiento, objetos, vínculo y dominio, investigación, racha y fragmentos.
- Vínculo +3 y **victorias** del Pokémon (`entry["wins"]`, sirven para evolucionar, ver [progresión](progresion.md)).
- Dominio +2 en cada movimiento usado en el combate.
- Investigación: tarea "Vencerlo en combate" de la especie.
- Objeto según el tipo del rival (`DROPS`, 45 % + 3 % por victoria de racha); con racha alta, raros (`RARE_DROPS`).
- **Racha de victorias** (`world_flags["win_streak"]`): se reinicia al desmayarte. Logro con 10.
- **Fragmento místico** de los fuertes (Alfa 80 % ×3; dominantes o evolucionados 30 %). Con 4 se fabrica cualquier MT (18 recetas).
- Fanfarria `bw1_victory_wild` (o `bw1_victory_trainer` contra entrenadores).

## Captura en combate (Fase 4)
- Al apuntar, el control pasa a **Nate**; tu Pokémon sigue peleando solo y el rival **sigue atacando** (cada ~4 s, 60 % de que vaya por ti).
- **Carga de potencia:** mantener lanzar sube y baja la potencia (0,9 s por subida); al soltar se lanza con esa fuerza (55–115 % de la velocidad). Barra "POTENCIA" con la **zona dorada** (≥ 82 %): **lanzamiento excelente**, ×1,5 a la captura (`ThrowAim.THROW_EXCELLENT_BONUS`).
- **Esquiva de Nate:** mientras apuntas en combate, Espacio / B lo lanza de lado (o hacia atrás) 0,3 s sin recibir daño; espera de 0,8 s.
- Fuera del combate el lanzamiento sigue siendo inmediato. Si la ball falla, el combate continúa; si captura, termina con la fanfarria `bw1_item`.

## Megaevolución
- Requiere la **Piedra Llave** (primer acertijo de ruinas resuelto) y la **megapiedra** de la especie (misiones del Rotom); Mega Rayquaza solo pide la Piedra Llave. Una vez por combate.
- Animación de 2,6 s (`MegaEffect`): rayo, esfera arcoíris, destello y "✦ MEGAEVOLUCIÓN ✦". El combate se detiene mientras dura.
- La mega usa una copia de la especie con sus estadísticas y tipos, y una hoja 2×4 hecha con los sprites de frente y espalda; tamaño ×1,3. Al terminar el combate (o al cambiar) vuelve a la normalidad.

## Interfaz
`BattleUI`: tarjeta del rival arriba (nombre, tipos y vida), la tuya abajo a la izquierda con retrato y aviso de mega, los 4 movimientos con su recarga, la barra de potencia y una fila de ayudas que cambia al apuntar.
