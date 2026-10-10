# Captura

[← Índice](../README.md) · Código: `world/capture/`, `core/game_state.gd`

## En el mundo (estilo Leyendas Arceus, Fase 2.8)
- **Apuntar** (clic derecho o LT): la cámara pasa al hombro, Nate camina más lento y aparece el arco de la trayectoria (misma gravedad que la física). Hay una mira en el centro.
- **Lanzar** (clic izquierdo o RT): Pokéball con física real (`RigidBody3D`). Descuenta una de `GameState.pokeballs` (20 al inicio; el inventario completo llega en la Fase 5).
- Si toca a un salvaje, este entra en la ball y hay **3 sacudidas**. Si falla en el suelo, rueda y desaparece a los 3 s.
- **Probabilidad** (`CaptureRules`), basada en la fórmula de los juegos:
  `p = ((3 − 2·PS%) / 3 · ratio oficial · ball · temperamento · bonos) / 255`
  - Temperamento: curioso ×1.15, deambula ×1, agresivo o territorial ×0.9, tímido ×0.85.
  - Aturdido ×2.5; **sigilo** ×2 (no te vio: está tranquilo y lanzas por la espalda o el costado).
  - Ejemplos: Bidoof sano 33 %, herido 87 %, aturdido 100 %, por sorpresa 67 %; Mewtwo sano 0.4 %.
  - Cada sacudida aguanta con probabilidad p^(1/3).
- **Éxito:** estrellitas y entra al equipo (`GameState.party`, máx. 6) o a la caja; si es legendario queda marcado como capturado. **Fallo:** sale de la ball; el agresivo o territorial se enoja contigo, los demás huyen, el legendario escapa volando o corriendo y el aturdido sigue aturdido.
- Los avisos aparecen arriba en el HUD ("¡Atrapaste a…!" o "¡… escapó de la Pokéball!").

## En combate (Fase 4, por hacer)
- Se mantiene la captura en primera persona dentro de la arena del combate (ver el [GDD](../GDD.md)).
