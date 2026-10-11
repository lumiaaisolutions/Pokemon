# Clima, estaciones y eventos del mundo

[← Índice](../README.md) · Estado: **hecho** (2026-10-10). Código: `world/weather/weather.gd`, `world/events/world_events.gd`, `world/day_night.gd`.

## Clima por bioma
- Cada **2 horas del juego** se decide el clima de cada bioma (determinista por semilla y hora); se ve el del bioma donde estás.
- Climas: despejado, nublado, lluvia, tormenta (relámpagos), nieve, ventisca, tormenta de arena, ceniza volcánica y niebla. Tablas por familia: templado, selva, seco, frío, volcán, sombrío (pantano y bosques oscuros) y costa.
- Efectos: partículas que siguen a la cámara, menos luz del sol y más niebla (DayNight) y **peso de aparición por tipo**: lluvia → Agua ×2.5; tormenta → Eléctrico ×3; nieve → Hielo ×4; arena → Tierra y Roca; ceniza → Fuego; niebla → Fantasma ×2.5; despejado → Fuego y Planta.
- En el HUD bajo el reloj: "Lluvia · Primavera". Adentro no hay clima. Con tormenta, ventisca o arena los habitantes se van a casa.

## Estaciones
Cada **7 días del juego**: Primavera (más lluvia), Verano (más sol y tormentas), Otoño (niebla y nublado; pasto y árboles anaranjados) e Invierno (en zonas templadas la lluvia cae como nieve; colores pálidos). El color se aplica con el uniforme global `season_tint` al pasto, la hierba alta y el follaje.

## Eventos (avisos del Rotom Móvil)
- **Brote masivo:** cada mañana 55 % de que una especie salga muchísimo (70 %) en una zona de 90 m cerca de un pueblo, todo el día.
- **Lluvia de estrellas:** 30 % de las noches; estrellas fugaces, Pokémon del espacio (Clefairy, Minior, Lunatone…) y un fragmento que cae cerca para recoger.
- **Pokémon dominante:** cada 2 minutos, 35 % de que aparezca uno grande (×1.5) y fuerte (vida ×2) cerca; aura dorada; premio: Pepita.
- **Territorios Alfa:** al acercarte (70 m) a uno vive un Alfa (×1.7, vida ×2.5, aura roja) una vez por día; premio: Caramelo Raro.
- **Clima extremo (2026-10-11, mundo más lleno):** cada mañana 15 % de que el Rotom avise que hoy el clima puede volverse extremo (tormenta eléctrica, ventisca o sequía fuerte) en algunas zonas (`WorldEvents.extreme_weather_today`). No cambia la generación determinista de `Weather.weather_for()` (la usan las pruebas de clima); por ahora es solo el aviso, ver `docs/decisiones_sin_preguntar.md`.
