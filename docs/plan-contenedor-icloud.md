# Plan: los datos al contenedor de iCloud de la app

*Borrador para revisar antes de tocar código. Noviembre de 2026.*

## Qué se quiere

Hoy cada aparato guarda sus datos en un sitio distinto:

- **Los Mac** leen y escriben en `iCloud Drive/Pauta` por ruta. Pueden hacerlo
  porque no están en sandbox.
- **El iPhone y el iPad** guardan en la carpeta del grupo de aplicaciones, que es
  local. Cruzan con la carpeta del Mac mediante el **Puente**, y para eso hay que
  elegir esa carpeta a mano, una vez por aparato, en el selector del sistema.

Esto tiene tres problemas:

1. Quien no tiene Mac no tiene con qué sincronizar el iPhone y el iPad. Para una
   app de la App Store es un agujero.
2. Elegir la carpeta a mano es frágil. El permiso caduca, el marcador se rompe,
   y el iPad hay que configurarlo aparte. Ahí hay código que se ha arreglado
   muchas veces.
3. El día que el Mac entre en sandbox (Mac App Store), deja de poder leer
   `iCloud Drive/Pauta` por ruta.

Con la cuenta de pago ya existe la alternativa buena: **un contenedor de iCloud
propio**, `iCloud.dev.jadrdev.pauta`. Los Mac, el iPhone y el iPad lo ven sin
elegir nada, y funciona igual dentro y fuera del sandbox.

## Corrección a lo que dije antes

Dije que con el contenedor desaparecería el Puente. **No del todo, y es mejor
así.** Hay dos maneras de hacerlo en el iPhone:

- **A. El almacén del teléfono vive directamente en el contenedor**, como hacen
  los Mac con su carpeta. Es lo más simple sobre el papel, pero:
  - El widget completa tareas desde su propio proceso (`CompletarTarea` abre un
    `Store()`). Necesitaría también acceso al contenedor, y una extensión
    escribiendo en iCloud a la vez que la app es terreno nuevo.
  - iOS desaloja archivos de iCloud cuando le falta espacio. Sin red, una tarea
    desalojada no se puede leer. Hoy el teléfono funciona sin red desde el
    primer día, y eso se perdería.
- **B. El teléfono sigue con su almacén local y el Puente cruza con el
  contenedor**, sin que nadie elija carpeta. El widget y el modo sin red quedan
  como están. Lo que desaparece es lo frágil: el selector, el permiso que
  caduca, el marcador, la pantalla de puesta a punto y la configuración aparte
  del iPad.

**Recomiendo B.** El Puente ya está probado: dieciséis pruebas lo cruzan con
lápidas, adjuntos y archivos a medio bajar, y lleva meses en uso. Lo que fallaba era
cómo llegaba a la carpeta, no cómo cruzaba. En los Mac no hay cambio de modelo:
el almacén apunta al contenedor igual que hoy apunta a `iCloud Drive/Pauta`.

## Fase 0 — Prueba, sin mover datos

Antes de escribir la mudanza, comprobar que todo lo que hace falta existe de
verdad. Ya pasó con el equipo personal: se dio por hecho que iCloud funcionaría
y Apple se negó a emitir el perfil.

1. Crear el contenedor `iCloud.dev.jadrdev.pauta` y activar *iCloud Documents*
   en los identificadores `dev.jadrdev.pauta` de iOS y de macOS. Lo hace Xcode
   al pedir los perfiles; si no, la web.
2. **El punto que no sé de antemano: un Mac firmado con Developer ID, ¿puede
   usar iCloud Documents?** Apple admite iCloud fuera de la App Store, pero hay
   que ver que emita el perfil de Developer ID con esa capacidad y que la app
   notarizada encuentre su contenedor. Si no lo emite, este plan cambia: el Mac
   se quedaría en `iCloud Drive/Pauta` y haría de puente.
3. Una compilación de prueba en el Mac y el iPhone que solo escriba un archivo
   en el contenedor y lea el del otro. **Sin tocar el almacén.**
4. Comprobar dónde aparece en Finder y en Archivos. Con
   `NSUbiquitousContainers` se puede elegir si se ve como una carpeta «Pauta» en
   iCloud Drive o queda oculto (decisión 1, abajo).

Si algo de esto falla, se para aquí y no se ha movido nada.

### Resultado (9 de noviembre de 2026): sigue adelante

- **El contenedor existe.** Xcode lo creó solo al pedir los perfiles con los
  entitlements de iCloud puestos, y activó *iCloud Documents* en los dos
  identificadores. No hizo falta la web.
- **Developer ID sí lleva iCloud.** El perfil «Mac Team Direct Provisioning
  Profile» trae el contenedor con entorno *Production*, y la app exportada para
  Developer ID lo encuentra en
  `~/Library/Mobile Documents/iCloud~dev~jadrdev~pauta/Documents`.
- **Llega en los dos sentidos.** `Pauta --contenedor` en el Mac y la app del
  iPhone lanzada con `-pruebaContenedor` dejan cada uno su marca. La del iPhone
  llegó al Mac en segundos. El iPhone vio las del Mac primero como «en iCloud»
  y las leyó en la siguiente apertura: es el desalojo de siempre, y el almacén
  ya sabe tratarlo.
- **Visible en iCloud Drive: pendiente.** Con `NSUbiquitousContainers` público y
  la app registrada, el Finder todavía no la enseña. La publicación la decide
  el servidor de iCloud y puede tardar. Se vuelve a mirar antes de la fase 2.

## Fase 1 — La red de seguridad, antes de cualquier mudanza

- Una copia completa del estado de antes, fuera de iCloud: la carpeta entera,
  incluidos los adjuntos, copiada a `~/Pauta antes de la mudanza <fecha>`. No en
  Documentos: con «Escritorio y Documentos» en iCloud, Documentos **es**
  iCloud. Las copias diarias en gzip siguen existiendo, pero esta se puede
  abrir con el Finder.
- La copia la hace la propia versión nueva, y **no sigue si la copia falla**.

### Resultado (9 de noviembre de 2026): hecha

`Mudanza.resguardar` pide a iCloud lo desalojado y espera a que baje. Copia a
una carpeta provisional, compara cada archivo byte a byte y solo entonces le
pone el nombre definitivo. Si algo no baja a tiempo, para y dice cuáles. Nunca
pisa una copia anterior. A mano: `Pauta --resguardo`.

Con los datos de verdad dio 384 archivos y 999 KB, idénticos al original
(`diff -r`). La copia está en `~/Pauta antes de la mudanza 2026-11-09`.

Lo que enseñó el primer intento: esperó tres minutos a treinta copias diarias
que ya estaban bajadas. Foundation guarda el estado de iCloud **en la propia
URL**, y preguntar a la misma devolvía «sin bajar» para siempre. Ahora pregunta
con una URL nueva cada vez. Comprobado desalojando dos copias con
`brctl evict`: esperó 1,7 segundos y las copió bien.

## Fase 2 — Los Mac se mudan (la versión 0.5.0, por ejemplo)

Al arrancar la versión nueva en un Mac:

1. Si iCloud no está disponible, sigue como hoy y no hace nada más.
2. **La mudanza es un cruce.** `Puente.cruzar(iCloud Drive/Pauta, contenedor)`,
   el mismo de siempre, con *gana la más reciente* y sin borrar nunca. Eso la
   hace **repetible**: si se corta a medias, en el siguiente arranque vuelve a
   cruzar y completa lo que faltaba sin duplicar nada. También sirve para los
   dos Mac: si se mudan a la vez, se cruzan los mismos archivos y el resultado
   es el mismo. Incluye los adjuntos, que el Puente ya sabe llevar, y las
   copias de seguridad.
3. **Se comprueba antes de cambiar de sitio:** las mismas tareas, proyectos y
   áreas en los dos lados, con la misma fecha cada una. Solo si cuadra, el
   almacén pasa a apuntar al contenedor. Si no cuadra, sigue en la carpeta de
   siempre y lo dice en Ajustes, en vez de mudarse a medias.
4. **La carpeta vieja no se borra.** Se deja dentro un `LEEME.txt` que dice que
   ya no se usa y desde cuándo.

**Mientras dure la transición**, en cada arranque y cada cierto tiempo, el Mac
mudado sigue cruzando contenedor ↔ carpeta vieja. Así, lo que se toque desde un
aparato todavía en la versión anterior (el otro Mac, o el iPhone con su Puente
a la carpeta vieja) llega al contenedor, y al revés. No hace falta actualizar
todo a la vez.

### Resultado (9 de noviembre de 2026): este Mac, mudado

`MudanzaDelMac` arranca con la app, en segundo plano. Hace la copia de antes,
`Mudanza.mudar` (el cruce, las copias diarias y la comprobación) y, si cuadra,
lo apunta en las preferencias de ese Mac. El almacén usa el contenedor desde el
arranque siguiente. Durante la transición cruza las dos carpetas al arrancar,
cada minuto y al salir. `Pauta --mudanza` dice en qué punto está.

En el MacBook Air tardó tres segundos: 354 archivos y 30 copias diarias
llevados, y cuadra. Las dos carpetas tienen 332 tareas, 19 proyectos y 3 áreas.
Al volver a abrir, el almacén lee del contenedor, con las mismas 305 tareas
vivas que antes.

Se adelantó un trozo de la fase 4: ya no se adopta la carpeta local al estrenar
iCloud. Con el cambio de carpeta, ese peligro latente se habría vuelto posible.

Pendiente: el otro Mac, cuando se abra con esta versión.

## Fase 3 — El iPhone y el iPad se mudan (misma versión, por TestFlight)

- El Puente cruza con el contenedor en vez de con la carpeta elegida.
- La primera vez, ese cruce **es** la mudanza: lo que el teléfono tenga y el
  contenedor no lo tenga, va; y al revés. No hace falta código especial.
- Para enterarse de los cambios, `NSMetadataQuery` sobre el contenedor, que es
  el mecanismo de Apple para esto. Sustituye al vigilante de la carpeta
  elegida. Se mantienen el cruce al volver a la app, al irse al fondo y el
  refresco en segundo plano.
- Desaparecen de la interfaz «Elegir la carpeta del Mac» y la puesta a punto.
  Si iCloud está apagado en el aparato, Ajustes lo dice y la app sigue en
  local, como hoy sin carpeta elegida.

## Fase 4 — Limpieza (una versión más tarde, cuando tú lo digas)

Cuando todos los aparatos lleven la versión nueva:

- Fuera el cruce con la carpeta vieja en los Mac.
- Fuera `CarpetaElegida`, el selector, `VigilanteDeCarpeta`, `iCloudRoot` y
  `adoptData`. **Esto último es un peligro latente de hoy**: si un Mac ve
  vacía `iCloud Drive/Pauta/items`, copia dentro lo que haya en
  `~/Library/Application Support/Pauta`. En este Mac eso son tareas de agosto.
- La carpeta vieja la borras tú cuando quieras. La app no la borra nunca.

## Lo que no cambia

- El formato: un archivo JSON por objeto, lápidas, *gana la más reciente*.
- El reloj: sigue hablando con el iPhone, no con iCloud.
- Los widgets del Mac y del iPhone: leen el vistazo de la carpeta del grupo.
- Las copias diarias: se mudan con todo lo demás y siguen funcionando igual.

## Pruebas

- **Del núcleo, con carpetas temporales:**
  - mudanza completa;
  - mudanza cortada a medias y repetida;
  - dos Mac mudándose a la vez;
  - un aparato viejo escribiendo en la carpeta vieja durante la transición;
  - comprobación que no cuadra y deja todo como estaba;
  - archivos a medio bajar en cualquiera de los dos lados.
- **En aparatos de verdad, en este orden:**
  1. este Mac;
  2. el otro Mac;
  3. iPhone;
  4. iPad.

  Entre paso y paso, comprobar en los demás que lo que se toca en uno llega.

## Decisiones que son tuyas

1. **¿Contenedor visible u oculto?** Visible, aparece como «Pauta» en iCloud
   Drive y sigues pudiendo copiar la carpeta como copia de seguridad, pero
   convivirá con la vieja, que también se llama «Pauta», hasta que la borres.
   Oculto, no se ve ni se toca, y la copia de seguridad queda solo en Ajustes.
   **Recomiendo visible.**
2. **A o B en el teléfono.** **Recomiendo B**, por lo explicado arriba.
3. **Cuándo acaba la transición.** Recomiendo que la acabes tú, cuando me digas
   que todos los aparatos están actualizados, y no por fecha. Tienes dos Mac,
   y uno puede pasarse semanas sin abrirse.

## Esfuerzo

- **Fase 0:** una sesión. Es la que decide si seguimos.
- **Fases 1 a 3:** dos o tres sesiones, con sus pruebas.
- **Fase 4:** una sesión corta, más adelante.
