# Plan: Pauta en inglés

*Borrador para revisar antes de tocar código. Noviembre de 2026.*

## Qué se quiere

Hoy Pauta existe en un solo idioma. El bundle declara solo el español
(`CFBundleLocalizations: [es]`), y cada texto está escrito en español dentro del
código. Quien tiene el iPhone en inglés, en alemán o en japonés ve en español la
ficha de la tienda y la app entera.

Se quiere **el inglés y solo el inglés**. Con él llega a la mayoría de quien no
habla español. Un tercer idioma no compensa todavía: hay que traducirlo,
revisarlo y mantenerlo en cada versión, y ninguno de los dos podemos juzgar si
un texto en alemán suena natural.

## Cómo, en una frase

**El español sigue siendo el idioma en que se escribe el código, y un catálogo
de textos de Xcode (`.xcstrings`) lleva al lado la traducción al inglés.** El
texto en español es la clave del catálogo. Así, en español la app no cambia ni
una letra, y las pruebas, que no cargan ningún catálogo, siguen viendo el mismo
español de siempre.

## Lo que hay hoy

Contado en el código, por encima:

| Dónde | Textos de pantalla | Cadenas con texto en español |
|---|---|---|
| Mac (`Sources/Pauta`) | ~150 | ~140 |
| iPhone y iPad (`Sources/PautaIOS`) | ~140 | ~60 |
| Núcleo (`Sources/PautaCore`) | — | ~40 |
| Reloj, widgets y esfera | ~15 | ~15 |

Unos 400 textos en total, contando repetidos. No es mucho. Lo que cuesta no es
el número, son cinco sitios donde el español va más allá de un texto suelto.

1. **El núcleo monta frases.** El repaso del día («3 sin hacer de días
   pasados», «"Regar" lleva 2 semanas sin fecha»), los avisos («Aplazar 10
   min», «Pendiente desde el 3 de octubre»), el widget («Nada para hoy», «1
   atrasada») y las duraciones («1 h 20 min») son `String` con interpolaciones.
   No pasan por `Text("…")`, así que nada las traduce solo.
2. **Dos sitios fijan el formato español a mano.** Son
   `Locale(identifier: "es_ES")` en `MismaCosa.swift` y en `Agenda.swift`. En
   inglés, esas fechas y comparaciones seguirían saliendo en español.
3. **Lo que se escribe.** `Cuando` saca el día y la hora de «Llamar a la
   gestoría mañana a las 10». La fecha la entiende `NSDataDetector`, que ya sabe
   inglés. Pero lo que viene después es español: las horas («a las», «h»,
   «horas») y las palabras sueltas que se quitan del título («el», «para»,
   «de»). Con «Call the accountant tomorrow at 10» encontraría la fecha y dejaría
   «at» pegado al título.
4. **El lector de calendarios pegados** (`Calendario.swift`) es español de
   arriba abajo: meses, días de la semana y las iniciales L M X J V S D.
5. **Siri y Atajos.** Las frases de `AppShortcut` («Apuntar en Pauta», «Añadir a
   Pauta») y los títulos de las acciones van en otro catálogo propio,
   `AppShortcuts.xcstrings`. Las frases inglesas no se traducen de las
   españolas: se escriben como diría alguien que habla inglés.

## El diseño

### Un solo catálogo para todos

El núcleo se compila como **biblioteca estática** dentro de cada app y de cada
extensión, así que no tiene un bundle propio. `String(localized:)` dentro del
núcleo busca en el bundle de quien lo ejecuta: la app del Mac, la del iPhone, el
widget o el reloj.

Por eso habrá **un `Localizable.xcstrings` compartido**, añadido como recurso a
todos los objetivos que muestran texto. Uno por objetivo sería repetir la misma
traducción siete veces y que acabaran distintas.

Lo que hay que comprobar en la fase 0 es si Xcode **extrae solo** las cadenas
del núcleo cuando están en una biblioteca estática. Si no, se añaden a mano o
con un guion. Hay que saberlo antes de empezar, no a mitad.

### Frases, no trozos

Cada frase se traduce entera, con sus huecos: `"\(n) sin hacer de días
pasados"`, no «sin hacer» por un lado y «de días pasados» por otro. En inglés el
orden cambia y los trozos no encajan.

Los plurales («1 atrasada / 3 atrasadas») van como **variantes de plural del
catálogo**, no con un `if n == 1` en el código. Hoy algunos están así, y hay que
cambiarlos.

### Fechas y números

- Fuera los dos `es_ES`. Se usa el idioma del sistema, como ya hace el resto.
- `Duracion` escribe «h» y «min» a mano. Se pasan al catálogo o se dejan en
  manos de `Duration.formatted`, que ya sabe de idiomas.
- Las fechas de los avisos («Pendiente desde el 3 de octubre») van con
  `formatted`, que ya respeta el idioma. Solo hay que traducir lo que las rodea.

### Los avisos ya programados

El texto de un aviso se fija cuando se programa, no cuando suena. Si alguien
cambia el idioma del teléfono, los avisos ya programados saldrían en el idioma
viejo. No hace falta nada nuevo: la app reprograma todos los avisos cada vez que
se abre, y al cambiar de idioma iOS reinicia las apps. Hay que comprobarlo, no
construirlo.

### Quien no habla ni español ni inglés

Si el teléfono está en alemán, iOS busca alemán, no lo encuentra y usa **el
idioma de desarrollo**, que hoy es el español (`CFBundleDevelopmentRegion: es`).
Un alemán vería Pauta en español. Lo normal es que vea inglés, y eso es una
decisión tuya (ver abajo). Si se elige el inglés, hay que comprobar en la fase 0
cómo se hace sin cambiar el idioma de partida del código.

### Lo que se queda en español

- **Las novedades.** La app las lee de las versiones de GitHub, y esas notas las
  escribimos en español. Traducir cada versión dos veces es trabajo para
  siempre. Propongo dejarlas en español y que el enlace diga «Release notes
  (Spanish)».
- **La guía** (el README de GitHub) y la **política de privacidad**
  (`docs/privacidad.md`). La de privacidad sí merece una versión en inglés,
  porque la tienda la enlaza. La guía puede esperar.
- **El lector de calendarios.** Ver decisiones.

## Antes de empezar

1. **Que aprueben la 1.0.0.** Lo mismo que con CloudKit: no se mezcla el estreno
   con cambios grandes.
2. **Ninguna versión intermedia a medio traducir.** La fase 1 se puede publicar,
   porque en español no cambia nada. Pero el inglés no se activa en el bundle
   hasta que la fase 2 esté entera: una app medio en inglés y medio en español
   es peor que una entera en español.

## Fase 0 — Prueba, con un texto de cada sitio

Antes de sacar 400 textos, comprobar el camino con **uno de cada clase**:

1. Un `Text` de una vista del iPhone y uno del Mac.
2. Una frase del núcleo con número y plural (el «1 atrasada / 3 atrasadas» del
   widget).
3. Un texto del reloj y otro de la esfera.
4. Un aviso.
5. Una frase de Siri.

Arrancar en el simulador con `-AppleLanguages "(en)"` y comprobar que salen los
cinco en inglés. Comprobar también:
- si Xcode extrae solo las cadenas del núcleo (ver «Un solo catálogo para
  todos»);
- qué se ve con el teléfono en alemán;
- que **las 407 pruebas siguen pasando** sin tocarlas.

Si algo de esto no funciona como se espera, el diseño cambia aquí, no en la
fase 1.

## Fase 1 — Sacar los textos, sin traducir nada

- Crear `Localizable.xcstrings` y `AppShortcuts.xcstrings`, y añadirlos en
  `project.yml` a cada objetivo.
- Pasar las cadenas del núcleo a `String(localized:)`, con frases enteras y
  plurales del catálogo.
- Quitar los dos `es_ES` y las «h» y «min» a mano.
- Los textos que no son para leer (claves de `UserDefaults`, identificadores,
  rutas) se marcan para que el catálogo no los recoja.

**Al acabar, en español la app es idéntica.** Comprobarlo con capturas antes y
después de las pantallas principales, en el Mac y en el iPhone. Esta fase se
puede publicar sola.

## Fase 2 — Traducir

Traducir no es poner cada palabra en inglés: es reescribir. Los textos de Pauta
tienen tono («Tus tareas no se tocan», «Un aviso que no llega y no lo dice es
peor que no tener avisos»). Hay que buscar cómo lo diría alguien que escribe así
en inglés.

Primero, **un glosario** con los nombres que salen en todas partes. Así se
traduce cada uno igual en las siete apps:

| Español | Propuesta |
|---|---|
| Bandeja | Inbox |
| Hoy | Today |
| Próximamente | Upcoming |
| Papelera | Trash |
| Proyecto / Área | Project / Area |
| Apuntar | Add (en Siri, «Add to Pauta») |
| Aplazar | Snooze |
| El repaso del día | Morning review |
| Valores de fábrica | Defaults |

Después, el catálogo entero. Lo traduzco yo, y tú repasas lo que no te suene
bien. Al final de esta fase se añade `en` a `CFBundleLocalizations`.

## Fase 3 — Lo que se escribe

- **`Cuando` en inglés:** horas («at 10», «10am», «10:30») y palabras sueltas
  («at», «on», «the», «for»), según el idioma del sistema. Con pruebas en inglés
  como las de ahora en español.
- **El lector de calendarios:** según lo que decidas (ver abajo).

## Fase 4 — La tienda

En App Store Connect, añadir **inglés (EE. UU.)** a la ficha:
- nombre, subtítulo, descripción, palabras clave y texto promocional;
- la URL de la política de privacidad en inglés;
- **capturas en inglés de todos los aparatos**: iPhone, iPhone Duo, iPad, Mac y
  reloj.

Para las capturas:
- la maqueta tiene que tener tareas de ejemplo en inglés, porque hoy están en
  español en `Store.swift`;
- `tools/capturas-tienda.py` necesita los titulares en inglés;
- la maqueta arranca con `-AppleLanguages "(en)"`.

Inglés de EE. UU. sirve para el Reino Unido y el resto. Si no se añade aparte,
la tienda lo usa en todos los países de habla inglesa.

## Fase 5 — Que no se rompa

Lo más fácil de perder es una cadena nueva que alguien escribe en español y
nadie traduce. En inglés saldría en español, sin avisar. Por eso:

- **Un guion** en `tools/` que falle si el catálogo tiene alguna entrada sin
  traducir o marcada como desfasada.
- `testflight.sh` y `make-dmg.sh` lo llaman antes de compilar. **Si falta una
  traducción, no se sube.**

## Lo que no cambia

- El español de la app, letra por letra.
- Los datos: las tareas no tienen idioma, y no se toca el almacén ni la
  sincronía.
- Las 407 pruebas actuales.
- El código sigue escrito en español: nombres, comentarios y mensajes de commit.

## Riesgos

- **Textos que no caben.** El inglés suele ser más corto que el español, pero no
  siempre, y la esfera del reloj y los widgets pequeños van justos. Hay que
  mirarlos uno por uno en la fase 2.
- **Un texto montado con trozos** que se escapa a la fase 1 y sale medio en
  inglés y medio en español. Lo que lo evita son las capturas en inglés de
  todas las pantallas.
- **El soporte.** Con la app en inglés llegarán correos en inglés a «Escribir al
  desarrollador». No es un riesgo técnico, pero es trabajo.

## Pruebas

- **Del núcleo:** las de ahora tal cual, más `Cuando` en inglés (fase 3) y las
  frases del repaso y del widget en los dos idiomas, incluidos los plurales.
- **En el simulador**, con `-AppleLanguages "(en)"` y con `"(de)"`: todas las
  pantallas del iPhone, del iPad y del Mac, el widget, el reloj, un aviso y Siri.
- **En español**, otra vez: capturas antes y después de la fase 1, para ver que
  no cambió nada.

## Decisiones que son tuyas

1. **Qué ve quien no habla ni español ni inglés.** **Recomiendo inglés**: un
   alemán o un japonés entiende antes inglés que español, y es lo que hacen
   casi todas las apps.
2. **El lector de calendarios.** Tres opciones:
   - que aprenda inglés (meses, días y las iniciales M T W T F S S, con la T y
     la S repetidas, que ya complican);
   - que se quede en español y la pantalla lo diga;
   - esconderlo en inglés.

   **Recomiendo que se quede en español y lo diga.** Nació de dos textos
   concretos tuyos, y nadie ha pedido la versión inglesa.
3. **Las novedades en inglés o solo en español.** Recomiendo solo en español,
   con el enlace avisándolo.
4. **El glosario.** Sobre todo «Bandeja» → Inbox y «El repaso del día» →
   Morning review, que son los que más se ven.
5. **Cuándo.** Recomiendo después de que aprueben la 1.0.0 y **antes de
   CloudKit**. Traducir no puede perder tareas de nadie y CloudKit sí, así que
   es mejor tener el inglés hecho cuando empiece lo arriesgado.

## Esfuerzo

- **Fase 0:** una sesión corta.
- **Fase 1:** dos sesiones, casi todo el núcleo y el Mac.
- **Fase 2:** una o dos sesiones, más tu repaso.
- **Fase 3:** una sesión, sobre todo pruebas.
- **Fase 4:** una sesión, casi toda de capturas.
- **Fase 5:** un rato.
