# Registro de decisiones

[← Índice](README.md)

Todas tomadas por Fernando el 2026-10-09, salvo las marcadas como *(Claude)*.

## Proyecto
- Proyecto **personal y privado**: se usan Pokémon reales (nombres y sprites); no se publica ni se distribuye.
- Repo propio en `Pokemon/` (el repo raíz de LUMIA ignora esta carpeta). Godot 4.7.2 estándar (GDScript tipado).
- Regla de documentación: un `.md` por tema, sin saturar un solo archivo.
- Orden por capas del [catálogo](catalogo_mundo.md); los tres biomas se adelantaron antes del combate.

## Arte
- Dirección de arte final: **HD-2D con gráficos de B2W2**. Antes se probaron greybox low-poly y el estilo Leyendas Arceus, y se descartaron.
- Jugador: Nate (hoja overworld de B2W2). La espalda generada por código no convenció.
- Pokémon en el mundo: sprites de seguidores (pokeemerald-expansion); en combate, gen5 / gen5ani.
- Tamaño por altura en escalones de píxel (×1, ×1.5, ×2 y ×3).
- Cámara libre de 360° con pitch de −20° a 80°.

## Pokémon y aparición
- Los 18 tipos oficiales y su tabla de efectividad.
- Las 1,025 especies aparecen por tipo y bioma; el roster de 16 queda como destacado de cada zona.
- Rareza por etapa y poder; pseudolegendarios solo en su zona y 10 veces más raros.
- Shiny 2 %; manadas 30 % (líder evolucionado raro, 5 % de manadas rivales cerca); cupo por zona; esconderse tras 1–3 min.
- Legendarios: todos, solo en santuarios, 10 % por visita, uno a la vez; reaparición del 2 % tras capturarlo; cautelosos (nunca atacan; "?" y escape volando o corriendo).
- Persecución: agresivos y territoriales, con área según el Pokémon; correr con stamina.
- Emboscadas: Bicho colgados y aves en las copas, con pistas y aviso.
- Peleas entre salvajes por rivalidades naturales; debilitado 5 s aturdido y luego humo.

## Jugador
- Salto (Espacio o B explorando; esquiva en combate). Vida con corazones (caídas, ataques, ahogarse). Nadar y bucear con aire.
- Desmayo: el compañero lo protege 2 min (máx. 2 atacantes); si cae, pantalla negra, pérdida de dinero y reaparición.
- *(Claude, por confirmar)* Si el compañero cae con Nate de pie, vuelve a su Pokéball y regresa a los 30 s con la mitad de la vida.

## Captura
- En el mundo estilo Leyendas Arceus (apuntar y lanzar con arco). Probabilidad por ratio oficial, vida, Pokéball, temperamento, sigilo y aturdido.
- Se mantiene la captura en primera persona dentro del combate (Fase 4).

## Progresión
- Sin niveles ni experiencia; evolución por desbloqueos.
- Inicial: 5 huevos al azar de básicos; eclosionan y Nate les lanza la Pokéball.
- Megaevolución: una vez por combate, jugador y jefe; Piedra Llave y megapiedra; animación estilo X/Y.
- Entrenadores NPC en la Fase 5.6 *(fase elegida por Claude a pedido de Fernando)*.

## 2026-10-09 — Tras probar la 2.8
- **Compañero debilitado → Centro Pokémon siempre** (antes regresaba a los 30 s). Pidió Fernando: "cuando me lo debilitan no me regresa ni al Centro Pokémon".
- **Nate desmayado → controlas al compañero** con golpe, ataque especial y esquivar, en lugar de la guardia automática. Nate se ve tirado en el suelo y la recuperación es visible (panel, barra, destellos).
- **Mira libre al apuntar**: la inclinación de la cámara se separa de la normal para lanzar hacia arriba o lejos.
- **Botón del compañero** (Q / △) para guardarlo o sacarlo.
- **Personajes**: 10 protagonistas de cada generación (5 y 5), con nombre y dificultad. Fernando prefirió a los protagonistas, aunque no comparten el estilo B2W2; se usan los sprites más cercanos (Gen 4 y fan de estilo DS).
- **Menú con pestañas** y todo su contenido, ver [plan](sistemas/menu_y_personaje.md).
