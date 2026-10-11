# Animaciones de ataques (pedido de Fernando, 2026-10-10 · en curso)

[← Índice](../README.md) · Estado: **lote 1 hecho** (base + los 6 pedidos); lotes 2 y 3 en curso.

## Hoy
- 744 movimientos (`creatures/data/moves.json`), 358 de daño. Los físicos son una embestida con polvo (`PixelBurst.DUST`); los especiales, un orbe de 5×5 píxeles del color del tipo (`world/effects/attack_projectile.gd`). La animación no depende del ataque (`world/actors/pokemon_actor.gd`, `use_move`).

## Pedido
"Usa Excavar que se vea que excava en la tierra y sale a atacarlo; Shuriken de Agua que lance un shuriken de agua; Lanzallamas que simule que lanza fuego; Llamarada una estrella de fuego; Látigo Cepa que salgan lianas que pegan al rival; Mordisco que al acercarse simule que lo muerde; y así con los necesarios, reciclando la animación donde corresponda."

## Decisiones (2026-10-10)
- **Familias** (cada una sirve a muchos ataques):
  1. **Bajo tierra / bajo el agua / en el aire:** Excavar, Buceo, Bote, Vuelo, Golpe Fantasma — se mete, se mueve oculto y sale bajo el rival.
  2. **Proyectiles con forma:** Shuriken de Agua (estrella de agua que gira), Llamarada (estrella de fuego), Bola Sombra, Esfera Aural, Bola Energía, Bomba Lodo…
  3. **Chorros y rayos:** Lanzallamas (chorro de fuego), Pistola Agua, Hidrobomba, Rayo Hielo, Rayo, Hiperrayo, Rayo Solar, Dragoaliento.
  4. **Lianas:** Látigo Cepa, Latigazo, Constricción.
  5. **Mordidas:** Mordisco, Triturar, Colmillo Ígneo/Hielo/Rayo/Veneno, Hipercolmillo — mandíbulas que se cierran sobre el rival.
  6. **Golpes y cortes:** puños elementales, A Bocajarro, Garra Dragón, Tajo Umbrío, Cuchillada.
  7. **Desde el cielo:** Trueno, Avalancha, Roca Afilada, Meteoro Dragón.
  8. **Suelo:** Terremoto (onda y temblor), Surf (ola).
  9. **Ráfagas y viento:** Hoja Afilada, Pin Misil, Tornado, Ataque Ala, Disparo Lodo.
  10. **Mejoras de estado:** Danza Espada (espadas alrededor), Maquinación, Paz Mental, Protección (escudo), Fortaleza.
- **Estilo:** pixel art como el mundo (sprites con brillo).
- **Impacto en ataques fuertes:** temblor de cámara, destello con pausa breve al pegar y marca en el suelo que dura unos segundos (quemadura, charco, grieta).
- **Más familias** (Fernando pidió más variedad y aceptó todas las recomendaciones, 2026-10-10):
  11. **Drenaje:** Megaagotar, Gigadrenado, Chupavidas, Absorber — orbes verdes del rival al atacante, que brilla.
  12. **Psíquico y Fantasma:** Psíquico levanta al rival con ondas moradas; Puño Sombra sale de la sombra del rival; Lengüetazo.
  13. **Hada y Hielo:** Brillo Mágico (destellos rosas en círculo), Fuerza Lunar (luna que cae), Ventisca (cono de nieve), Canto Helado (carámbanos).
  14. **Auras de carga:** Envite Ígneo, Voltio Cruel, Acua Jet, Pájaro Osado, Ataque Rápido — cubierto de fuego, rayos, agua o viento, embiste con estela.
  15. **Saltos aplastantes:** Golpe Cuerpo, Patada Salto, Pisotón, Martillo Dragón — salta y cae con onda en el suelo.
  16. **Clima y terreno:** Danza Lluvia, Día Soleado, Granizo y Tormenta Arena cambian el clima unos minutos; Campo de Hierba o Eléctrico pintan el suelo.
  17. **Explosiones:** Explosión, Autodestrucción, Bomba Germen, Pulso Umbrío — estallido en anillo con humo.
  18. **Estados alterados:** Polvo Veneno, Somnífero, Onda Trueno, Fuego Fatuo — nube o chispa sobre el rival e ícono del estado sobre su cabeza.
  19. **Sonido y multigolpe:** Vozarrón, Chirrido, Canto (ondas y notas); Doble Bofetón, Ataque Furia, Pin Misil (golpes con contador ×2, ×3…).
  20. **Trampas en el suelo:** Púas, Trampa Rocas, Púas Tóxicas, Red Viscosa — quedan en la arena y dañan al pisarlas.
  21. **Ida y vuelta:** Ida y Vuelta, Voltiocambio, Viraje — golpea y vuelve a la ball; sale otro de tu equipo.
  22. **Avisos de eficacia:** estrellas en el crítico y texto flotante "¡Es muy eficaz!" / "No es muy eficaz".
  23. **Firmas de legendarios:** Aerochorro, Rugido del Tiempo, Corte Vacío, Pulso Primigenio, Filo del Abismo, Ascenso Draconico, Psicoataque… con animación única.
  24. **Definitivos de iniciales:** Planta Feroz (raíces gigantes), Anillo Ígneo (columna de fuego), Hidrocañón (cañonazo de agua), con temblor.
  25. **Bajar estadísticas y copias:** Malicioso (mirada), Gruñido (ondas), Encanto (corazones); Doble Equipo (clones), Sustituto (muñeco), Transformación.
- **Propuesta por confirmar:** los ataques que no entren en una familia usan la animación de su tipo y clase (como hoy, pero con la forma del tipo).

## Implementación
- **Base (lote 1, 2026-10-10):** `world/effects/move_fx/pixel_shapes.gd` (formas pixel art por código: shuriken en 4 cuadros de giro, estrella de fuego, llama, gota, liana, hoja, mandíbulas con colmillos de color, montículo, roca, estrella, orbe y marcas de suelo: grieta, quemadura, charco), `move_families.gd` (qué familia usa cada ataque) y `move_fx.gd` (reproduce la familia y llama al daño en el momento del impacto). `PokemonActor.use_move` llama a `MoveFx.play`; los ataques sin familia usan la animación de siempre.
- **Extras de impacto** (ataques de potencia 90+): temblor de cámara (`CameraRig.shake`), destello del golpeado (`instance uniform flash` del shader de sprites) y marca en el suelo 5 s. **Avisos de eficacia:** "¡Es muy eficaz!", "No es muy eficaz…" y "¡Golpe crítico!" flotan sobre el rival (`PokemonActor.float_text`).
- **Lote 1:** Excavar/Buceo/Vuelo/Bote/Golpe Fantasma (se oculta, avanza como montículo, burbujas o sombra y sale bajo el rival), Shuriken de Agua (3 shurikens girando), Llamarada (estrella que crece y estalla), proyectiles con forma (Bola Sombra, Esfera Aural…), chorros (Lanzallamas, Hidrobomba, Pistola Agua… gotas seguidas que crecen), lianas (Látigo Cepa, Latigazo) y mordidas (Mordisco, Triturar, Colmillos de tipo). Capturas: `~/Desktop/Pokemon_ataques_lote1.png`.
