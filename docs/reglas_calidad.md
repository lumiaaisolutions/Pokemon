# Reglas de calidad visual y de mundo

[← Índice](README.md) · Reglas de Fernando (2026-10-10, noche) tras probar el juego. **Son permanentes:** se aplican a todo lo nuevo y, si se detecta algo que las rompe en cualquier parte del juego, se corrige (aunque no sea la tarea actual). Si para cumplirlas hacen falta recursos (modelos, sprites, sonidos), se consiguen pidiendo permiso para cada descarga. Nunca se asume un diseño: se pregunta a Fernando con opciones y una recomendación.

## Mundo y objetos
1. **Nada plano que deba tener volumen:** árboles, rocas, arbustos, flores, cactus, hierba alta, mobiliario y estructuras van en **3D estilo B2W2** (modelos reales de B2W2 donde existan; si no, 3D propio de pocas caras con textura pixel). Los personajes y Pokémon siguen como sprites de mundo (estilo HD-2D).
2. **Física real:** todo lo sólido tiene colisión que cubre su forma completa. No se atraviesan paredes, fachadas, puertas, mobiliario ni estructuras (ni el jugador, ni la gente, ni los Pokémon). Al saltar sobre algo bajo (banca, maceta, caja) te quedas encima.
3. **Nada flotando ni encimado:** todo apoyado en el suelo o en su mueble; nada atravesando otra cosa; nada fuera de su cuarto o edificio.
4. **Sin zonas negras ni huecos:** ninguna pared, piso o cara faltante; nada de cajas oscuras visibles tapando modelos; ningún piso caminable fuera de las paredes.
5. **Edificios completos:** cada edificio se ve como lo que es (tienda, centro, laboratorio, gimnasio, casa…), con su **puerta visible al frente, hacia la calle**, justo donde está "Entrar".
6. **Luz:** los interiores tienen luz propia cálida (nunca oscuros); de noche los faroles alumbran de verdad y nada se ve negro; todos los modelos siguen la luz del día y la noche (nada con colores fuera de lugar de noche).
7. **Cámara:** solo choca con paredes grandes y terreno; no hace zoom de golpe por cercas, plantas o mobiliario.

## Personajes y Pokémon
8. **Solo sprites de mundo** (hojas de caminar estilo B2W2) en el mundo; nunca sprites de frente de batalla ni de menú. Sin huecos ni pixeles sueltos en los sprites.
9. **Cada puesto lo atiende quien corresponde:** dependientes humanos en tiendas, la enfermera en el Centro; los Pokémon de interior solo como mascota o ayudante de alguien, en su lugar.
10. **La gente habla en la caja de diálogo** con su nombre y retrato (no con avisos sueltos), y reacciona con burbujas cortas según el contexto.
11. **La gente no se atraviesa en medio** de escenas importantes ni camina a través de cosas.
12. Los objetos en mano (Poké Ball al sacar o guardar) salen de la **mano**, no de la cabeza.

## Juego
13. **Nunca dejar al jugador sin saber qué hacer:** instrucciones claras en cada paso nuevo.
14. **IA con estrategia:** los Pokémon en combate no solo persiguen y pegan; rodean, toman distancia, esquivan y atacan según su carácter.

## Cómo se aplica
- Antes de dar algo por hecho: capturas desde varios ángulos (de día y de noche, por fuera y por dentro) y revisarlas.
- Pruebas automáticas cuando se pueda (colisiones de edificios, nada flotando, luz mínima).
- Cada problema nuevo que reporte Fernando se agrega aquí si es una regla general.
