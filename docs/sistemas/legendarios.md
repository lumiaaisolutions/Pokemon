# Legendarios y singulares

[← Índice](../README.md) · Código: `world/actors/legendary_manager.gd`, `PokemonActor.legendary`, `core/game_state.gd`

- Solo aparecen en **10 santuarios**: 2 en la pradera, 2 en el bosque, 2 en la montaña (uno es la cumbre más alta), 1 en agua dulce, 1 en la costa y 1 en el pantano. Las construcciones de cada santuario (ruinas, árbol sagrado, volcán…) llegan en la capa 2.6.
- **10 % por visita:** al llegar a un santuario (50 m) puede aparecer uno de los legendarios de ese hábitat. Al irte (130 m) se retira.
- **Nunca hay dos del mismo.** Si ya lo capturaste, solo vuelve con la tirada del 2 % por sesión (`GameState.is_legendary_available`).
- **Cautelosos:** nunca atacan ni provocan combate.
  - Te **ven** en un cono frontal de 16 m o te **oyen** a 5 m (11 m si corres): muestran "?" y escapan.
  - Los de tipo Volador y los dragones grandes **vuelan** en arco 45 m; los demás **corren** por un camino real que no pasa junto a ti.
  - Acercarse por detrás y sin correr permite verlos de cerca; además da el bono de sigilo en la [captura](captura.md).
- La hora del día y el clima como condición (Suicune con lluvia, Darkrai de noche…) llegan con la capa 2.7.
