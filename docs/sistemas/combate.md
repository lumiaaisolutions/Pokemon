# Combate en tiempo real y megaevolución (Fases 3 y 4, por hacer)

[← Índice](../README.md)

## Combate (Fase 3)
- **Inicio:** al contacto con un salvaje (o al verte un entrenador, [Fase 5.6](progresion.md)) se genera una arena circular de unos 15 m en ese mismo punto, con borde visual. El mundo alrededor se pausa y la cámara pasa detrás de tu Pokémon.
- **Control directo:** moverse, esquivar (salto o dash con invulnerabilidad breve y gasto de stamina, botón Espacio o B), fijar objetivo (Tab o R3) y 4 movimientos (1–4; X, Y, LB y RB).
- **Movimientos:** físicos (golpe o embestida a corta distancia) y especiales (proyectil, cono o área con indicador en el suelo). Campos: tipo, categoría, poder, gasto de stamina, recarga, alcance y preparación (aviso).
- **IA salvaje:** avisa sus ataques con indicador en el suelo y tiempo de preparación; su agresividad depende del temperamento y la rareza (no hay niveles).
- **Daño:** estadísticas, poder, tabla de tipos oficial (`TypeChart`, ya hecha), STAB ×1.5 y azar 0.85–1.
- **Salidas:** huir (salir del borde, con recarga), victoria (sin experiencia; recompensa por definir) o captura.
- Estadísticas fijas por especie: sin niveles ni experiencia (todo parejo).
- Sprites de combate: gen5 / gen5ani de frente y espalda (animado si existe; si no, estático con animación procedural); variocolor y megas incluidos.

## Captura en combate (Fase 4)
- Primera persona dentro de la arena: mira, carga de potencia y Pokéball con física. El Pokémon sigue moviéndose y atacando; Nate esquiva y tiene aguante. Tres sacudidas; si falla, sigue el combate. Ver también la [captura en el mundo](captura.md), ya hecha.

## Megaevolución
- **Quién:** el Pokémon del jugador y el jefe del bioma 3; una vez por combate (G o cruceta arriba). Al terminar el combate vuelve a la normalidad.
- **Requisitos:** Piedra Llave (lugar fijo del mundo) y la megapiedra de la especie equipada (por misiones, [Fase 5.5](progresion.md)). Antes de la 5.5 se prueba con los objetos equipados en modo debug.
- **Animación estilo X/Y (2.5–3 s, el combate se pausa):** rayo de la Piedra Llave a la megapiedra, esfera de luz arcoíris, destello blanco y aparición de la mega con su símbolo (partículas y shaders).
