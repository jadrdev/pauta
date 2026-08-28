# Pauta

Gestor de tareas para macOS. Nativo en SwiftUI, con los datos en un archivo
local y sin suscripción.

Pauta organiza el trabajo en dos ejes: **cuándo** y **de qué**. Una tarea entra
por la bandeja sin que tengas que decidir nada más que el título. Desde ahí le
pones fecha —y aparece en Hoy o en Próximamente—, la aparcas en Algún día, o la
metes en un proyecto.

Las listas de la barra lateral no son carpetas: son **consultas** sobre ese
estado. Una tarea con fecha de hoy que pertenece a un proyecto sale a la vez en
Hoy, en Cualquier momento y en su proyecto, sin duplicarse. Cambiar su fecha la
mueve de lista sola.

## Las listas

| Lista | Qué contiene |
|---|---|
| Bandeja | Sin fecha, sin proyecto y sin aparcar: lo que aún no has decidido |
| Hoy | Planificadas para hoy o antes, más lo que tenga la **fecha límite encima**. Una tarea vencida sigue apareciendo aquí |
| Próximamente | Planificadas para más adelante, **agrupadas por día** |
| Cualquier momento | Lo que se puede hacer ya: Hoy más las tareas de proyecto sin fecha. La bandeja queda fuera: lo que hay allí aún está sin decidir |
| Algún día | Aparcadas a propósito, sin fecha |
| Completadas | Lo hecho, lo más reciente primero |

Los **proyectos** aparecen debajo, cada uno con su cuenta de tareas abiertas.

Una tarea de proyecto sin fecha sale en `Cualquier momento` a propósito: meterla
en un proyecto ya es decidir que se va a hacer, solo falta cuándo. Fuera de su
propio proyecto, cada tarea lleva el nombre del proyecto —con su emoji— en una
pastilla a la derecha, que es lo que permite distinguir dos tareas que se llamen
igual.

«Sin fecha» y «Algún día» son estados distintos, y esa distinción es el centro
del modelo: el primero significa «todavía no lo he decidido» y deja la tarea en
la bandeja; el segundo, «lo quiero hacer, pero no ahora». Por eso ponerle fecha
a una tarea aparcada la saca de Algún día — estar aparcada y con fecha a la vez
sería contradictorio.

## Cómo se usa

| Atajo | Acción |
|---|---|
| `⌘N` | Nueva tarea en la lista actual |
| `⌘⇧N` | Nuevo proyecto |
| `↩` | Guardar y seguir escribiendo otra tarea |
| `esc` | Cancelar la tarea nueva |
| `⌘⇧R` | Importar de Recordatorios |
| `⌘1` … `⌘6` | Bandeja / Hoy / Próximamente / Cualquier momento / Algún día / Completadas |

Una tarea nueva nace ya encajada en la lista donde la creas: en Hoy sale con la
fecha de hoy, en Próximamente con la de mañana, en Algún día aparcada, y dentro
de un proyecto asignada a él.

Clic en una tarea la despliega para editar título, notas, fecha, repetición y
proyecto; se guarda mientras escribes, sin botón de guardar. El menú de fecha
tiene atajos para hoy, mañana y la semana que viene, y **«Otra fecha…» abre un
calendario** para cualquier día. Clic derecho abre las acciones
rápidas: programar, aparcar o eliminar.

**Arrastrar** hace dos cosas según dónde sueltes:

- Sobre una **lista de la barra lateral**, mueve la tarea a esa lista. Como las
  listas son consultas y no carpetas, mover es cambiar lo que hace que la tarea
  caiga ahí: a `Hoy` le pone la fecha de hoy, a `Algún día` la aparca, a la
  bandeja le quita fecha y proyecto. Dos detalles: a `Próximamente` se respeta una
  fecha futura que ya tuviera en vez de adelantarla a mañana, y arrastrar una
  completada a una lista de pendientes la reabre — si no, iría a un sitio donde no
  se ve y parecería perdida.
- Sobre **otra tarea**, la coloca justo antes: es la prioridad manual. Una línea
  marca dónde va a caer. Soltar sobre «Añadir» la manda al final.

La prioridad es **una sola para toda la app**, no una por lista: las listas son
consultas sobre la misma tarea, así que su prioridad es intrínseca y todas la
respetan. En `Próximamente` manda el día, y el orden manual solo ordena dentro de
cada día.

Pegar un texto de varias líneas en el campo de nueva tarea crea **una tarea por
línea**, quitando viñetas (`*`, `-`, `•`) y numeración. Cuando existan las listas
de comprobación, este será el punto donde elegir entre tareas sueltas o una sola
tarea con lista.

Cada proyecto puede llevar un emoji: se elige pulsando el círculo junto a su
título, de una paleta corta, y sustituye a su símbolo en la barra lateral.

## Captura desde Recordatorios

Recordatorios de Apple sincroniza por iCloud y funciona con Siri, así que hace
de bandeja de entrada remota: lo que apuntes en el iPhone aparece en Pauta sin
necesidad de una app de iOS.

La app usa **una lista propia llamada «Pauta»**, que crea al arrancar si no
existe, y nunca toca tus otras listas. Al importar, cada recordatorio entra en la
bandeja y **se marca completado en Recordatorios**, para que fluya en vez de
acumularse. Cada tarea guarda el identificador de origen, así que si el marcado
fallara no se duplicaría en la siguiente importación.

Se importa al arrancar la app y con `⌘⇧R`. El permiso se pide la primera vez; si
lo deniegas, la app funciona igual sin la captura remota. Ojo: **una vez
denegado, macOS no vuelve a preguntar** y hay que activarlo a mano en Ajustes →
Privacidad y seguridad → Recordatorios.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --reminders-status
./build/Pauta.app/Contents/MacOS/Pauta --import-reminders
./build/Pauta.app/Contents/MacOS/Pauta --seed-reminder "Título"
```

Diagnóstico, importación manual y siembra de un recordatorio para probar la
integración sin tocar el iPhone. Requieren que el permiso ya esté concedido: TCC
no puede presentar su diálogo en un proceso lanzado desde el terminal, porque
atribuye la petición al proceso responsable, que es la consola.

Escribir tareas de Pauta como recordatorios, en cambio, no está previsto: duplica
y obliga a resolver conflictos en los dos lados.

## Fechas límite

Una cosa es **cuándo pienso ponerme** (la fecha de planificación) y otra **cuándo
tiene que estar** (la fecha límite). Son campos distintos: se puede tener una
entrega el viernes sin haber decidido aún qué día ponerse, y esa tarea se queda en
la bandeja hasta que lo decidas.

Pero una fecha límite que no avisa no sirve de nada, así que **cuando vence
arrastra la tarea a `Hoy`** aunque no estuviera planificada. Lo aparcado en `Algún
día` se respeta: aparcarlo fue una decisión explícita.

En la lista, la fecha límite se muestra a la derecha: apagada mientras queda
margen, y en rojo con un triángulo cuando es hoy o ya pasó. En rojo solo cuando
aprieta — si todas gritaran, ninguna diría nada. Al completar la tarea el aviso se
apaga: ya no hay nada que entregar.

## Tareas repetitivas

Una tarea puede repetirse cada día, semana, mes o año. Al **completarla**, la
completada se queda en el historial y **nace la siguiente** con la fecha
avanzada, heredando notas y proyecto.

Esa es la decisión que importa: la alternativa —mover la misma tarea hacia
adelante— dejaría sin rastro de lo hecho, que es justo lo que uno quiere ver de
una rutina.

La siguiente fecha se cuenta **desde el día que tenía asignado, no desde hoy**:
completar tarde una tarea semanal no debe desplazarle el día para siempre.

Y descompletar retira la sucesora si nadie la ha tocado, porque marcar y desmarcar
acumularía copias. Por eso cada sucesora recuerda de cuál nació.

### Desde cuándo y hasta cuándo

**El inicio no es un campo aparte: es la fecha de la tarea.** Una semanal puesta
para el 1 de septiembre empieza ahí. Guardarlo dos veces solo daría ocasión de que
los dos valores discreparan, así que en una tarea repetitiva la fecha se muestra
como «Desde el 1 sept», que es lo que ya significaba.

**El fin sí es un campo**, y es opcional: `recurrenceEnd`, con `nil` para lo que
no acaba nunca, que es el caso normal. Cuando la siguiente repetición caería más
allá de esa fecha, la última se completa y no nace ninguna más. Las sucesoras
heredan el fin — si no, la serie volvería a ser infinita en la segunda vuelta.

Quitar la repetición borra también su fin: un «hasta» sin repetición no significa
nada.

## Barra de menús

El monograma junto al reloj abre un panel con las tareas de Hoy: completarlas
con su casilla, añadir una nueva (que cae en Hoy) y reabrir la ventana
principal, todo sin cambiar de app. Cubre casi todo lo que daría un widget sin
necesitar extensión ni firma — WidgetKit exige un `.appex` embebido que no encaja
con el empaquetado actual por SwiftPM y firma ad-hoc.

## Compilar y ejecutar

```bash
./run.sh
```

Compila y abre la app. Solo `./build.sh` genera `build/Pauta.app` sin lanzarla —
puedes arrastrarla a `/Applications` cuando te guste cómo va.

```bash
swift test
```

Los tests cubren `PautaCore`, que no depende de la interfaz.

### Firma

`build.sh` firma con la primera identidad «Apple Development» del llavero que no
esté revocada, o con la que fuerces en `SIGN_ID`. Si no encuentra ninguna, cae a
firma ad-hoc y lo avisa.

No es un detalle cosmético. Con firma ad-hoc el hash del binario cambia con cada
cambio de código, y TCC —el sistema de permisos— identifica las apps por su
firma: cada build sería una app nueva para el sistema, así que los permisos de
calendario, recordatorios o accesibilidad se pedirían otra vez en cada
compilación, dejando entradas basura en Ajustes de Privacidad.

Con una identidad de desarrollador el requisito designado pasa a basarse en el
identificador y el certificado:

```
designated => identifier "dev.jadrdev.pauta" and anchor apple generic
              and certificate leaf[subject.CN] = "Apple Development: …"
```

Comprobado: tras un cambio real de código el `cdhash` cambia y ese requisito no,
así que los permisos concedidos sobreviven a las recompilaciones. Esto es lo que
desbloquea las integraciones con Calendario y Recordatorios.

La letra pequeña: los certificados «Apple Development» caducan (el actual, en
mayo de 2027). Cuando caduque habrá que renovarlo y volver a conceder permisos.

No hace falta abrir Xcode, pero sí tenerlo instalado: los scripts usan
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` porque
`xcode-select` de este equipo apunta a las Command Line Tools. Si algún día
cambias eso (`sudo xcode-select -s /Applications/Xcode-beta.app`), los scripts
siguen funcionando.

## Dónde se guardan los datos

**Un archivo JSON por objeto**, con escritura atómica, en iCloud Drive:

```
~/Library/Mobile Documents/com~apple~CloudDocs/Pauta/
  items/<uuid>.json
  projects/<uuid>.json
```

Si iCloud Drive no está activo, la app usa `~/Library/Application Support/Pauta/`
con la misma estructura y funciona igual, solo sin sincronizar. Al estrenar la
carpeta de iCloud adopta lo que hubiera en la local, y deja el original intacto
como respaldo.

No se usa `url(forUbiquityContainerIdentifier:)`: esa vía exige entitlements y un
perfil de aprovisionamiento embebido, que no encajan con un bundle montado a
mano. iCloud Drive es una carpeta normal y la app no está en sandbox, así que
escribe en ella directamente.

Copiar la carpeta es la copia de seguridad; borrarla deja la app a cero. Para ver
el estado guardado sin abrir la interfaz:

```bash
./build/Pauta.app/Contents/MacOS/Pauta --dump
```

### Por qué un archivo por objeto

Antes era un único `data.json` con todo. Esa forma es la peor posible para
sincronizar: dos dispositivos que añaden **tareas distintas** escriben versiones
incompatibles del mismo archivo, y una de las dos tareas se pierde en silencio.
No hace falta simultaneidad, basta que uno estuviera sin conexión un rato.

Con un archivo por objeto, tocar tareas distintas no genera ningún conflicto, y
un archivo corrupto solo se lleva su propia tarea en vez de todo el almacén.
Cada mutación escribe **solo el objeto tocado**: reescribir todo agitaría las
fechas de modificación de archivos intactos, que es justo lo que hace trabajar de
más a la sincronización.

Borrar **no elimina el archivo: deja una lápida** (`deletedAt`). Si se eliminara,
un dispositivo que no vio el borrado resucitaría la tarea al sincronizar.

Esa protección caduca: pasados **30 días** todos los dispositivos han
sincronizado y la lápida ya no protege de nada, así que su archivo se borra al
arrancar. Sin eso se acumularían para siempre, leyéndose en cada carga. El precio
es que un dispositivo apagado más de un mes podría resucitar lo que borraste.

Las **completadas no se borran nunca**: son tu historial, y eliminarlas solas
sería perder datos sin haberlo pedido. Si algún día molestan, lo suyo es un
comando manual, no una purga automática.

### El orden de la lista

Las fechas se guardan en ISO8601, cuya precisión máxima es el **milisegundo**.
Dos tareas creadas en el mismo milisegundo —pegar varias líneas, por ejemplo—
tendrían la misma fecha, y como `sorted` no garantiza estabilidad y el orden de
los archivos en el directorio es arbitrario, **la lista se reordenaría entre
arranques**.

Por eso hay dos medidas: al crear una tarea se fuerza que su fecha sea al menos
un milisegundo posterior a la última (lo que hay que preservar es el orden, no el
instante), y todos los ordenamientos usan `Item.byCreation`, que desempata por
identificador para ser un orden total.

La migración desde el `data.json` antiguo aplica lo mismo respetando el orden que
tenía el array, porque sus fechas solo tenían segundos y casi todas empataban.
El archivo original se conserva como respaldo; puedes borrarlo cuando compruebes
que todo está en su sitio.

### Sincronización

Dos cosas que iCloud impone y la app resuelve:

**Archivos desalojados.** Para ahorrar espacio, iCloud puede dejar un archivo sin
contenido local y sustituirlo por un marcador `.nombre.json.icloud`. Al cargar, la
app pide su descarga; es asíncrona, así que esa carga no lo verá pero la siguiente
sí. `--dump` avisa de cuántos quedan pendientes.

**Conflictos.** Cuando dos dispositivos tocan el mismo archivo, iCloud guarda las
versiones en conflicto en vez de elegir. La app se queda con la de `updatedAt` más
reciente y marca las demás como resueltas — si no se marcaran, el conflicto se
quedaría ahí para siempre. Que la decisión salga del contenido del archivo y no de
su fecha en disco la hace determinista: los dos dispositivos eligen lo mismo.

**Refresco en vivo.** La app vigila la carpeta con FSEvents y recarga cuando algo
cambia, así que lo que llegue de otro dispositivo aparece sin reabrirla. Se usa
FSEvents y no `DispatchSource.makeFileSystemObjectSource`: este último solo se
entera de altas y bajas de entradas en un directorio, no de que cambie el
contenido de un archivo que ya existía — que es justo lo que hace iCloud al traer
una edición remota.

La recarga es **idempotente**: si lo leído coincide con lo cargado, no toca nada.
Hace falta porque las escrituras de la propia app también disparan el vigilante,
y una recarga que reasignara en vano refrescaría la interfaz e interrumpiría la
edición en curso. Para que esa comparación funcione, las fechas se sellan ya
redondeadas al milisegundo, que es la precisión con la que se guardan: si no, el
valor en memoria nunca coincidiría con el del archivo y toda recarga parecería un
cambio.

### Decodificación

Las tareas y los proyectos se leen con un `init(from:)` escrito a mano que usa
`decodeIfPresent` para todo. No es un capricho: el `Codable` sintetizado de Swift
usa `decode` para las propiedades no opcionales e **ignora sus valores por
defecto**, así que añadir un campo nuevo haría fallar la lectura de los archivos
ya guardados con un `keyNotFound`. Con el decodificador tolerante, los campos que
se añadan en el futuro no rompen los datos existentes.

## Diseño

Monograma «P» con check verde, sans geométrica, verde de marca sobre casi negro
azulado. Sigue el tema claro/oscuro del sistema.

- **Verde `#10E888`** como acento único. Marca la lista activa, los contadores y
  la casilla completada.
- **Iconos monocromos** en la barra lateral, un paso más tenues que la etiqueta,
  en verde solo cuando la fila está activa. El multicolor rompería el acento
  único. Los símbolos evitan chocar con otros significados de la interfaz: un
  check para Completadas competiría con la casilla de completar, y una estrella se
  lee como «favorito», no como «hoy» — de ahí el archivador y el sol.
- **Sin emojis** en las listas fijas: se renderizan distinto según el sistema,
  son multicolor y no alinean. En los proyectos del usuario sí, porque ahí la app
  no puede adivinar un símbolo.
- **Dos columnas de alineación** en la barra lateral: glifos a 15 pt y texto a 41
  (15 + 17 de columna de icono + 9 de espaciado). El rótulo de sección y el botón
  de nuevo proyecto respetan ambas.
- **La barra lateral va sin cabecera de marca.** El icono del Dock ya identifica
  la app; un logo dentro de su propia interfaz solo come espacio vertical. El
  lockup (`BrandMark` en `Theme.swift`) se mantiene sin usar, para un panel
  «Acerca de» o una pantalla de bienvenida.
- **Dos variantes del monograma** en `Resources`: `monogram.png` (P blanca, para
  fondo oscuro) y `monogram-ink.png` (P en negro de marca, para fondo claro).
  Cuando se muestre el lockup, el wordmark «PAUTA» se compone con tipografía y
  tracking en vez de traerse como PNG: nítido a cualquier tamaño y sigue el tema
  sin necesitar dos versiones.
- **Liquid Glass** en lo que se levanta de la página: el editor desplegado de una
  tarea. En macOS anterior a 26 cae a fondo sólido con filete.

### Contraste

El verde puro sobre fondo claro da **1.56** — ilegible. La paleta separa dos
tokens: `accent` para rellenos, bordes y fondos de selección, y `accentInk` para
cualquier cosa que sea texto (verde profundo `#097D49` en tema claro). El *tint*
de la app usa `accentInk`, porque los `Menu` sin borde colorean su etiqueta con
él e ignoran el `foregroundStyle`.

Los grises (`inkSoft`, `inkFaint`) se resolvieron numéricamente para pasar WCAG
AA (≥ 4.5) sobre los cuatro fondos. Si cambias un fondo, recalcúlalos.

## Iconos

`tools/make-icon.py` compone los `.icns` desde `Resources/monogram*.png`:

| Variante | Qué es |
|---|---|
| `icon-mono` | Monograma blanco sobre el negro de marca. **La que está puesta** |
| `icon-claro` | Monograma oscuro sobre fondo claro |

```bash
python3 tools/make-icon.py ambas
ICON=icon-claro ./build.sh
```

Al ser un monograma y no un wordmark, el mismo arte funciona de 16 a 1024 px sin
necesitar versiones distintas por tamaño.

### Limitación conocida del arte actual

El monograma se extrajo de un *mockup* con fondo, sombras y resplandor
incrustados, filtrando por color y quedándose con las componentes conexas
grandes. Funciona, pero a 512 px se aprecian dos defectos: una muesca en el brazo
de la P y un fragmento de la línea oscura que separa el check en el diseño
original — un detalle de tres colores que una extracción a dos no puede
representar. A tamaño de Dock (128 px) no se ven.

Con un SVG o un PNG a 1024+ con fondo transparente se regenera todo perfecto en
un comando: sustituye `Resources/monogram.png` y ejecuta `make-icon.py`.

## Modo maqueta

Para revisar el diseño sin tocar tus datos reales: arranca con tareas de muestra
en memoria, que no se escriben en disco, y permite forzar la apariencia.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --demo --light
./build/Pauta.app/Contents/MacOS/Pauta --demo --dark --view 3
```

`--view 1…6` elige la lista de arranque, en el orden de la barra lateral.
Combinado con `--dump` inspecciona la maqueta en vez de los datos reales.

## Estructura

```
Sources/PautaCore/        librería sin UI: la compartirán widget/iOS/sync
  Models.swift            Item, Project, Perspective
  Store.swift             estado + persistencia + consultas
Sources/Pauta/            la app de macOS
  PautaApp.swift          punto de entrada, menús, atajos y barra de menús
  Views/Theme.swift       paleta, tipografía y filetes
  Views/SidebarView.swift barra lateral
  Views/ItemListView.swift lista y cabecera
  Views/ItemRowView.swift fila, casilla y editor desplegado (Liquid Glass)
  Views/MenuBarView.swift panel de la barra de menús
Tests/PautaCoreTests/     tests del núcleo (swift test)
```

## Qué falta (siguiente iteración)

- **Eventos del calendario en Hoy**, solo lectura, para que Hoy sea el día
  completo y no solo la lista de tareas. Los eventos no deben entrar en el
  `Store`: acabarían persistidos en `data.json` como copias que se
  desincronizan. Van como fuente aparte, mezclada en la vista. Escribir tareas
  como eventos, en cambio, es mala idea: duplica y genera conflictos
- **Arrastrar entre días en `Próximamente`.** Ahora soltar sobre una tarea de otro
  día cambia la prioridad pero no la fecha, así que parece que no pasa nada
- **Fusionar en vez de recargar entero.** Al detectar un cambio se relee toda la
  carpeta. Con cientos de tareas conviene releer solo lo que cambió
- Áreas que agrupen proyectos
- Listas de comprobación y etiquetas (y la elección al pegar varias líneas)
- Arrastrar para reordenar
- Sincronización entre dispositivos
- Widget y app de iOS — necesitan proyecto de Xcode y cuenta de desarrollador;
  `PautaCore` ya está extraído para ese salto
