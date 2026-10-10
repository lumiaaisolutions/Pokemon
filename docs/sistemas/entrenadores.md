# Entrenadores en los caminos (Fase 5.6, hecha)

[← Índice](../README.md) · Código: `world/npc/route_trainers.gd` y `BattleManager.start_trainer`. Prueba: `tests/test_battle.tscn` (sección 9).

Decidido por Fernando: recompensa de **dinero y un objeto**; **revancha cada día**.

## Dónde están
- Cada ~260 m de camino (`SPACING`), fuera de pueblos (45 m) y lugares especiales, hay un entrenador a 3,5 m a un lado, **mirando el camino**. Los lugares son fijos por semilla del mundo.
- Clase según el bioma (Bichero en el bosque, Montañero en la montaña, Nadadora en la playa, Médium en el pantano…) y nombre y aspecto al azar (los sprites de los 10 protagonistas).
- Se crean a menos de 110 m y se liberan a más de 160 m (o al entrar a un interior).

## Cómo retan
1. **Campo de visión:** cono de 13 m y 32° hacia el camino, sin obstáculos en medio, y tú caminando.
2. Aparece **"¡!"** sobre él, suena el aviso (`spotted` y la fanfarria `bw1_spotted`) y camina hacia ti.
3. A 2,6 m dice su frase y empieza el **combate en arena** con su equipo; sus Pokémon salen de a uno junto a él ("X saca a Y (2/3)").
4. Si tu Pokémon no está fuera, te pide que lo saques y vuelve a su lugar (reintenta a los 12 s). También puedes hablarle (E) para retarlo.

## Equipo y premio
- Cambian **cada día** (semilla: entrenador + día + mundo). 2 a 4 Pokémon de la zona, sin legendarios; lejos del pueblo inicial son más y suelen estar evolucionados.
- Premio: $300 × Pokémon × (1 + 2 × lejanía) y un objeto (Poción, Super Ball… hasta Caramelo Raro lejos del inicio).
- No se capturan (la ball rebota). Si sales del círculo, te retiras y no cuenta.
- Vencido, dice "Mañana quiero la revancha" y no vuelve a retarte ese día (`world_flags["trainer_beaten:<id>"]`). Logro con 10 entrenadores.
- Música de combate: `bw2_battle_trainer2` o `bw1_battle_trainer`.
