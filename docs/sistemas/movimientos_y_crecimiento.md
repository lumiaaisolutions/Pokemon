# Movimientos y crecimiento sin niveles (plan)

[← Índice](../README.md) · Decidido con Fernando el 2026-10-09. Estado: **plan** (se implementa con el combate, Fase 3; el control del compañero con el jugador desmayado lo usará).

## Movimientos
- Cada especie usa su **lista oficial** de PokeAPI (por nivel, MT y tutor).
- Empieza con 4 movimientos básicos y desbloquea el resto: usándolo, con su investigación (Pokédex), con MT halladas en el mundo y con tutores.
- Lleva **4 movimientos** en cualquier mezcla de físicos y especiales (2 y 2, 1 y 3, 4 especiales…). Se cambian fuera de combate.
- **Sin PP:** cada movimiento tiene su tiempo de espera.
- **Dominio:** 3 rangos por movimiento que suben al usarlo (más potencia, menos espera, mejor alcance).
- **Estilos** al lanzarlo (como en Leyendas Arceus): **Fuerte** hace más daño con más espera; **Ágil** hace menos daño pero sale rápido.

## Crecimiento (sin niveles)
- **Puntos de Entrenamiento:** se ganan peleando, entrenando, con comida y con investigación, y se reparten en las 6 estadísticas con tope (+31 por estadística, 127 en total, como los EV). Así todos pueden mejorar lo mismo.
- **Vínculo** (1 a 10): sube con todo lo que hacen juntos y da bonos especiales: aguantar un golpe letal, esquivar mejor y críticos.
- **Equilibrio:** las estadísticas base se **comprimen hacia el promedio**. Un Pichu no queda a la par de Mewtwo, pero la diferencia baja de unas 3 veces a unas 1.6 veces. Las evoluciones y los legendarios siguen siendo más fuertes, y el entrenamiento y la estrategia pesan más.
  - Fórmula propuesta: `base_efectiva = 70 + (base − 70) × 0.5`, más los Puntos de Entrenamiento (a calibrar en la Fase 3).
