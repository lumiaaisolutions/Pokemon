# Peleas en el mundo

[← Índice](../README.md) · Código: `PokemonActor` (estados FIGHT y STUNNED), `creatures/data/type_chart.gd`, `world/effects/`

No es el combate de la Fase 3 (arena en tiempo real controlando a tu Pokémon): son las peleas que ocurren solas en el mundo abierto.

## Vida y ataques
- Vida en el mundo = 20 + PS base × 0.6, con barra flotante (verde, amarilla o roja) visible solo si no está llena.
- **A distancia** (si su At. Especial supera su Ataque): orbe del color de su tipo que viaja en línea recta, esquivable. **Cuerpo a cuerpo** en el otro caso: embestida.
- Destello de aviso 0.45 s antes de cada golpe; recarga de 1.4 a 2.4 s.
- Daño = 6 × (ataque / defensa) × STAB 1.5 × efectividad (tabla oficial de 18 tipos) × azar (0.85–1).

## Rivalidades (cada 1.5 s buscan rival a 9 m)
- Enemigos clásicos: Zangoose contra Seviper, Heatmor contra Durant, Mightyena contra Poochyena, Absol contra Mightyena.
- Manadas rivales: pelean si alguna es agresiva o territorial.
- Agresivos contra más débiles (30 puntos totales menos) o contra los que tienen desventaja de tipo; territoriales contra intrusos en su zona.
- Los tímidos no inician peleas y huyen si los golpean.

## Debilitado
- **Aturdido 5 s** con estrellitas girando: es la ventana de [captura](captura.md) más fácil (×2.5).
- Si nadie lo captura, desaparece en **humo** (estilo mob de Minecraft). El ganador queda herido.

## Contra el jugador
- Los agresivos y territoriales que te persiguen te golpean al alcanzarte (de 1 a 6 de vida). Si huyes a tiempo, solo te persiguen dentro de su área.

## Compañero
- **Defensa:** pelea con el salvaje que persigue o ataca a Nate a 12 m o menos.
- **Guardia** con Nate desmayado: se queda a su lado y enfrenta a quien entre a 8 m, con **2 atacantes como máximo** (los demás huyen).
- Si cae con Nate desmayado: desmayo definitivo. Si cae con Nate de pie: vuelve a su Pokéball y regresa a los 30 s con la mitad de la vida (*supuesto de Claude, por confirmar con Fernando*).
