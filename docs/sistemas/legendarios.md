# Legendarios y singulares

[← Índice](../README.md) · Código: `world/actors/legendary_manager.gd`, `PokemonActor.legendary`, `core/game_state.gd`

- Solo aparecen en **santuarios** del mundo generado: los 8 lugares "santuario" (círculo de piedra con altar; su hábitat es el del lugar donde cayeron), el **Santuario de la Cumbre** (el punto más alto fuera de la cordillera del borde, con explanada plana), la orilla de un lago (agua dulce) y un faro (mar). Cada hábitat tiene al menos uno.
- **10 % por visita:** al llegar a un santuario (50 m) puede aparecer uno de los legendarios de ese hábitat. Al irte (130 m) se retira.
- **Nunca hay dos del mismo.** Si ya lo capturaste, solo vuelve con la tirada del 2 % por sesión (`GameState.is_legendary_available`).
- **Cautelosos:** nunca atacan ni provocan combate.
  - Te **ven** en un cono frontal de 16 m o te **oyen** a 5 m (11 m si corres): muestran "?" y escapan.
  - Los de tipo Volador y los dragones grandes **vuelan** en arco (por encima del punto más alto entre salida y llegada, aunque bajen de una cumbre); los demás **corren** por un camino real que no pasa junto a ti.
  - Acercarse por detrás y sin correr permite verlos de cerca; además da el bono de sigilo en la [captura](captura.md).
