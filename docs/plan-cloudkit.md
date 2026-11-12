# Plan: sincronizar con CloudKit

*Borrador para revisar antes de tocar código. Noviembre de 2026.*

## Qué se quiere

Hoy los aparatos se ponen de acuerdo **por archivos**: cada tarea es un JSON en
el contenedor de iCloud de la app (`iCloud.dev.jadrdev.pauta`), y el Puente
cruza carpetas archivo a archivo, gana el más reciente. Funciona, pero tiene
techo:

1. **No es tiempo real.** Un aparato se entera de un cambio cuando iCloud Drive
   le baja el archivo y algo —el vigilante de carpeta, `NSMetadataQuery`, volver
   a abrir la app— dispara un cruce. Entre segundos y minutos, según el humor de
   iCloud.
2. **Es lento donde más se nota.** En el iPad, los cruces medidos tardan de 6 a
   11 segundos. La primera vez que un aparato se muda tiene que bajar y releer
   todo, y ahí es donde sospechamos el bloqueo de Ajustes del iPad.
3. **Depende de que los archivos estén bajados.** Medio Puente es código para
   lidiar con archivos que existen pero no están en el disco (`enLocal`, las
   descargas pedidas, los «sin bajar de iCloud» del balance).

Con **CloudKit**, cada tarea es un registro en la base de datos privada del
usuario. Un cambio sube como registro, el servidor avisa a los demás aparatos
con una notificación silenciosa, y bajan **solo ese registro**. Sin archivos,
sin descargas a medias, en segundos.

## Cómo, en una frase

**Cada aparato sigue guardando sus tareas en local, como hoy, y `CKSyncEngine`
las sube y baja.** Ni SwiftData ni Core Data: el almacén de JSON, las lápidas,
las copias diarias, exportar e importar, el widget y todas las pruebas que
tienen siguen igual. Lo que cambia es **con qué** se cruza: en vez de una
carpeta, el servidor.

`CKSyncEngine` pide iOS 17, macOS 14 y watchOS 10, que son justo los mínimos de
Pauta. No hay que subirlos.

## El diseño

### Registros

- Una **zona propia**, `Pauta`, en la base de datos **privada**: es la cuenta
  de iCloud del usuario, cuenta contra su espacio, y el desarrollador no ve
  nada. La política de privacidad sigue siendo verdad tal como está.
- Tres tipos de registro, uno por carpeta de hoy: `Item`, `Project` y `Area`.
  El nombre del registro es el UUID del objeto.
- **Cada registro guarda el objeto entero como JSON** en un campo `json`, y al
  lado dos campos sueltos: `updatedAt` y `deletedAt`. Es la decisión
  importante del plan, por esto:
  - **El esquema de CloudKit, una vez en producción, solo crece**: se pueden
    añadir campos, nunca quitarlos ni cambiarles el tipo. Con un campo por
    propiedad, cada cambio del modelo sería un cambio de esquema para siempre.
    Con el JSON dentro, el modelo evoluciona como hoy (`decodeIfPresent` y
    valores por defecto) y el esquema no se toca.
  - Es exactamente lo que hay hoy en cada archivo. La regla de «gana el más
    reciente» se aplica igual, con el mismo `updatedAt`.
  - Lo que se pierde es poder consultar el servidor por campos. Pauta no lo
    necesita: cada aparato tiene todo en local y filtra ahí.
- Un registro tiene un límite de 1 MB. Una tarea normal ocupa unos pocos KB;
  si alguna pasa de 700 KB (notas gigantes), el JSON va como `CKAsset` en vez
  de en el campo. Una prueba lo cubre.

### Adjuntos

- Tipo de registro `Adjunto`, con el fichero como `CKAsset`. El nombre del
  registro es `<id de la tarea>/<nombre>`, como la ruta de hoy.
- Un adjunto **no cambia nunca** (ya es así hoy), así que no tiene conflictos:
  o está o no está.
- Se bajan cuando se abre la tarea, no todos al arrancar. Un iPhone no necesita
  el PDF de una tarea de hace un mes hasta que la abres.

### Conflictos

La regla de siempre: **gana el `updatedAt` más reciente**. Cuando el servidor
rechaza un cambio porque otro aparato subió antes (`serverRecordChanged`), se
comparan las dos fechas: si gana la de aquí, se vuelve a subir sobre el
registro del servidor; si gana la del servidor, se guarda la del servidor en
local. Es la misma comparación que hace hoy `Puente.cruzar`, y se reaprovecha.

### Borrados

Como hoy: **un borrado es una lápida** (`deletedAt`), que viaja como un cambio
más. Pasados los 30 días de las lápidas, el aparato que la purga en local
borra también el registro del servidor. Si dos aparatos lo intentan a la vez,
el segundo encuentra el registro ya borrado y no pasa nada.

### El estado de la sincronía

`CKSyncEngine` necesita guardar por dónde va: qué cambios del servidor ya ha
visto y qué cambios locales faltan por subir. Ese estado es **de cada
aparato**, y por eso va en una carpeta local que no se sincroniza nunca. Si
fuera al contenedor de iCloud, dos Mac compartirían el mismo marcador y cada
uno se saltaría los cambios del otro.

### Quién avisa a quién

- **El Mac** recibe las notificaciones silenciosas en la app. Con la app
  cerrada no hay sincronía, igual que hoy no hay cruce.
- **El iPhone y el iPad** las reciben aunque la app esté en segundo plano, y
  despiertan para bajar el cambio, actualizar el widget y avisar al reloj.
- **El widget** completa tareas desde su propio proceso, escribiendo en el
  almacén del grupo. No sincroniza él: la app lo sube la próxima vez que
  despierta, o en el refresco en segundo plano que ya existe.
- **El reloj**, en la primera versión, sigue hablando con el iPhone como hoy. La
  sincronía directa del reloj es una fase aparte y opcional (fase 5).

### Lo que se pierde

- **Ver los datos en el Finder.** Las tareas dejan de estar en una carpeta de
  iCloud Drive. Siguen las copias diarias en local, y **Exportar una copia**
  para llevarlas a donde quieras.
- **La sincronía sin cuenta de iCloud.** No cambia nada: hoy tampoco la hay.
  Sin iCloud, cada aparato con lo suyo.

## Antes de empezar

1. **Que aprueben la 1.0.0** y ver qué dicen los primeros usuarios. Cambiar la
   sincronía la semana del estreno es mezclar dos fuentes de problemas.
2. **Cerrar la fase 4 del contenedor** (`plan-contenedor-icloud.md`), cuando me
   digas que el otro Mac y el iPad están actualizados. Hoy los Mac todavía
   cruzan la carpeta vieja de iCloud Drive con el contenedor. **No se empieza
   una mudanza con la anterior sin cerrar.**

## Fase 0 — Prueba, sin tocar datos

Como con el contenedor: comprobar que todo lo que hace falta existe de verdad
antes de escribir nada que dependa de ello.

1. Activar **CloudKit** en el contenedor `iCloud.dev.jadrdev.pauta` (hoy solo
   tiene *iCloud Documents*), y **las notificaciones** (`aps-environment`) en
   los identificadores de iOS y de macOS.
2. **El Mac va por Developer ID, no por la Mac App Store.** CloudKit funciona
   ahí, pero el perfil tiene que llevar el servicio, y la app firmada para
   distribuir necesita `com.apple.developer.icloud-container-environment` en
   `Production` puesto a mano. Comprobarlo con una compilación notarizada de
   verdad, no con la de depuración.
3. Una orden escondida, `Pauta --cloudkit-prueba` en el Mac y su andamio en el
   iPhone, que escribe un registro en una zona de prueba, `Prueba`. Comprobar:
   - que el otro aparato lo lee;
   - que **la notificación silenciosa llega** y en cuánto tiempo;
   - que funciona en una compilación de TestFlight. **TestFlight usa el entorno
     de producción de CloudKit**, no el de desarrollo: lo que funciona desde
     Xcode puede no funcionar en TestFlight si el esquema no está desplegado.
4. Borrar la zona `Prueba` y quitar el andamio.

**Si algo de esto falla, el plan se para aquí**, como pudo pasar con el
contenedor.

## Fase 1 — El núcleo, sin interfaz

En `PautaCore`, un módulo `Sincronia` probado de punta a punta antes de que
ninguna app lo use:

- La conversión objeto ↔ registro (JSON dentro, `updatedAt` y `deletedAt` al
  lado), y el caso del JSON grande como `CKAsset`.
- La resolución de conflictos, reutilizando la comparación del Puente.
- La cola de cambios locales: el almacén ya sabe qué objeto escribe en cada
  `persist`. Basta con que apunte su id para subirlo.
- Lo que llega del servidor entra en el almacén por el mismo camino que hoy
  entra lo que trae un cruce, con la misma regla.
- **Un protocolo delante de `CKSyncEngine`**, para probar sin red con un motor
  de mentira:
  - dos aparatos que tocan tareas distintas;
  - los dos tocando la misma tarea;
  - un borrado contra una edición;
  - un aparato que pasa una semana sin red y vuelve;
  - una lápida caducada;
  - la cuenta de iCloud que cambia a media sincronía.

## Fase 2 — Los Mac

1. **El almacén del Mac sale del contenedor** y pasa a una carpeta local nueva,
   **al lado** de las de hoy y no dentro: `~/Library/Application Support/dev.jadrdev.pauta`.
   - No vale `Application Support/Pauta`: ahí siguen las tareas de agosto de la
     época anterior a iCloud, y no se tocan.
   - Tampoco una subcarpeta suya: en un Mac sin iCloud, esa carpeta **es** su
     almacén de hoy, y la copia de antes de la mudanza se copiaría a sí misma.
   - Venga de donde venga —el contenedor, o la carpeta local de quien no usa
     iCloud—, la mudanza es la misma: copia de antes, cruce y comprobación.
2. Copia completa de antes, como en la mudanza al contenedor (`Mudanza.resguardar`).
3. **Primera subida**: todo lo local sube a CloudKit. Si otro Mac ya subió, lo
   que llega se cruza con la regla de siempre.
4. **La transición**: mientras quede algún aparato en una versión anterior, el
   Mac nuevo sigue cruzando su almacén con el contenedor de iCloud con el
   Puente, igual que hoy cruza la carpeta vieja. Así lo que toca un aparato
   viejo llega a CloudKit, y al revés.
5. Probar en este Mac, y luego en el otro.

## Fase 3 — El iPhone y el iPad

El almacén ya es local (la carpeta del grupo), así que no hay mudanza de
carpeta: solo cambia con qué se cruza.

- `CKSyncEngine` en lugar de `Sincronizar.conICloud`.
- Notificaciones silenciosas activadas (*Remote notifications* en los modos en
  segundo plano).
- Durante la transición, **un solo aparato** cruza con el contenedor de
  archivos: el Mac de la fase 2. Que cruzaran todos sería volver a tener dos
  sincronías peleándose.
- Ajustes: la sección iCloud se queda en una línea («Sincronizado con iCloud ·
  hace 10 s») y el botón «Cruzar ahora» pasa a «Sincronizar ahora», por si
  acaso.

## Fase 4 — Limpieza (cuando tú lo digas)

Cuando todos los aparatos lleven la versión nueva:

- Fuera el Puente, la `Mudanza`, el cruce de la transición, los vigilantes de
  carpeta y `NSMetadataQuery`.
- El contenedor de archivos se queda declarado (quitarlo no ganaría nada), pero
  la app deja de escribir en él. La carpeta la borras tú cuando quieras. La app
  no la borra nunca.

## Fase 5 — El reloj, por su cuenta (opcional)

Hoy el reloj ve lo que el iPhone le manda, y apunta a través del iPhone. Con
CloudKit podría sincronizar solo, y ver tareas nuevas sin el iPhone cerca. Pero
el reloj tiene poca batería y poca memoria, y lo de hoy funciona: **solo si
echas de menos que vaya solo.**

## Lo que no cambia

- El formato de cada objeto, las lápidas y la regla de *gana el más reciente*.
- El almacén local en cada aparato: sin red, todo sigue funcionando.
- Las copias diarias y exportar e importar.
- Los widgets: leen el vistazo de la carpeta del grupo.
- Sin cuentas, sin servidor propio y sin analíticas. La política de
  privacidad no hay que cambiarla: los datos van a tu iCloud, como hoy.

## Riesgos

- **El esquema en producción es para siempre.** Por eso el JSON dentro. Antes
  de la primera versión que salga, revisar el esquema en la consola de
  CloudKit y desplegarlo a producción a mano.
- **Una cuenta llena.** Si al usuario no le cabe nada más en iCloud, CloudKit
  rechaza las subidas. Hay que decirlo en Ajustes, no fallar en silencio.
  Hoy pasa lo mismo y no se dice.
- **Cambio de cuenta.** Si alguien cierra sesión en iCloud y abre otra, no se
  puede mezclar lo de una cuenta con la otra. Ver las decisiones de abajo.
- **Dos sincronías a la vez durante la transición.** Por eso solo cruza
  archivos un aparato, y por eso hay que cerrar antes la transición del
  contenedor.

## Pruebas

- **Del núcleo**, con el motor de mentira de la fase 1. Además, las 407 de
  ahora tienen que seguir pasando sin tocarlas.
- **En aparatos de verdad, en este orden:**
  1. este Mac;
  2. el otro Mac;
  3. iPhone;
  4. iPad;
  5. reloj, que solo tiene que seguir viendo lo mismo que el iPhone.

  Entre paso y paso, comprobar en los demás que lo que se toca en uno llega,
  y **cronometrarlo**: el objetivo es menos de 10 segundos con las dos apps
  abiertas.
- **Sin red:** tachar en el iPhone en modo avión, editar lo mismo en el Mac,
  volver a conectar. Tiene que ganar lo último que se hizo.

## Decisiones que son tuyas

1. **El objeto entero como JSON o un campo por propiedad.** **Recomiendo el
   JSON**, por lo del esquema para siempre. Un campo por propiedad solo
   compensaría si algún día otra cosa —una web, otra plataforma— leyera
   directamente de CloudKit.
2. **Qué pasa si se cierra sesión en iCloud.** Mi propuesta: las tareas se
   quedan en el aparato y se deja de sincronizar. Y si luego se entra con
   **otra** cuenta, preguntar antes de subir nada: «Estas tareas eran de otra
   cuenta de iCloud: ¿subirlas a esta o empezar en blanco?». Lo que no haría
   nunca es borrarlas sin preguntar.
3. **El reloj por su cuenta (fase 5): sí, no o más adelante.** Recomiendo más
   adelante.
4. **Cuándo.** Recomiendo empezar la fase 0 cuando esté aprobada la 1.0.0 y
   cerrada la transición del contenedor, y no antes.
5. **Jira u otras plataformas.** CloudKit no ayuda con eso: hablar con Jira
   necesita un servidor o hacerlo desde cada aparato. Es otra decisión, y este
   plan no la cierra ni la complica.

## Esfuerzo

- **Fase 0:** una sesión. Es la que decide si seguimos.
- **Fase 1:** dos sesiones, casi todo pruebas.
- **Fases 2 y 3:** dos o tres sesiones, con aparatos de verdad.
- **Fase 4:** una sesión corta, más adelante.
- **Fase 5:** una o dos sesiones, si se hace.
