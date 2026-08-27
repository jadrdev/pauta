# Pauta

Gestor de tareas para macOS. SwiftUI nativo, datos en local, sin suscripción.

## Identidad

Monograma «P» con check verde, sans geométrica, verde de marca sobre casi negro
azulado.

- **Verde `#10E888`** como acento único. Marca la lista activa, los contadores y
  la casilla completada.
- **Iconos monocromos** en la barra lateral, un paso más tenues que la etiqueta,
  en verde solo cuando la fila está activa. Nada de multicolor: los iconos de
  colores distintos (bandeja azul, estrella amarilla, check verde) son una de las
  señas de Things, y además romperían el acento único. Por eso «Hoy» usa un sol y
  no una estrella, y «Registro» un archivador y no un check.
- **Sin emojis** en las listas fijas: se renderizan distinto según el sistema, son
  multicolor y no alinean. Los proyectos del usuario sí pueden llevar uno: se
  elige pulsando el círculo junto al título del proyecto, de una paleta corta, y
  sustituye al símbolo del proyecto en la barra lateral.
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
- Sigue el tema claro/oscuro del sistema.

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

Al ser un monograma y no un wordmark, el mismo arte funciona de 16 a 1024 px: no
hace falta arte distinto por tamaño, como sí requería el logo de lettering
anterior (guardado en `Resources/legacy/`).

### Limitación conocida del arte actual

El monograma se extrajo de un *mockup* con fondo, sombras y resplandor
incrustados, filtrando por color y quedándose con las componentes conexas
grandes. Funciona, pero a 512 px se aprecian dos defectos: una muesca en el brazo
de la P y un fragmento de la línea oscura que separa el check en el diseño
original — un detalle de tres colores que una extracción a dos no puede
representar. A tamaño de Dock (128 px) no se ven.

Con un SVG o un PNG a 1024+ con fondo transparente, se regenera todo perfecto en
un comando: sustituye `Resources/monogram.png` y ejecuta `make-icon.py`.

## Compilar y ejecutar

```bash
./run.sh
```

Compila y abre la app. Solo `./build.sh` genera `build/Pauta.app` sin lanzarla —
puedes arrastrarla a `/Applications` cuando te guste cómo va.

No hace falta abrir Xcode, pero sí tenerlo instalado: los scripts usan
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` porque
`xcode-select` de este equipo apunta a las Command Line Tools. Si algún día
cambias eso (`sudo xcode-select -s /Applications/Xcode-beta.app`), los scripts
siguen funcionando.

## Atajos de teclado

| Atajo | Acción |
|---|---|
| `⌘N` | Nueva tarea en la lista actual |
| `⌘⇧N` | Nuevo proyecto |
| `↩` | Guardar y seguir escribiendo otra tarea |
| `esc` | Cancelar la tarea nueva |
| `⌘1` … `⌘6` | Bandeja / Hoy / Próximamente / Cualquier momento / Algún día / Registro |

Clic en una tarea para desplegarla y editar notas, fecha o proyecto.
Clic derecho para programarla o eliminarla.

Pegar un texto de varias líneas en el campo de nueva tarea crea **una tarea por
línea**, quitando viñetas (`*`, `-`, `•`) y numeración. Cuando existan las
listas de comprobación, este será el punto donde elegir entre tareas sueltas o
una sola tarea con lista.

## Barra de menús

El monograma junto al reloj abre un panel con las tareas de Hoy: completarlas
con su casilla, añadir una nueva (que cae en Hoy) y reabrir la ventana
principal, todo sin cambiar de app. Cubre casi todo lo que daría un widget sin
necesitar extensión ni firma — WidgetKit exige un `.appex` embebido que no
encaja con el empaquetado actual por SwiftPM y firma ad-hoc.

## Modo maqueta

Para revisar el diseño sin tocar tus datos reales: arranca con tareas de muestra
en memoria (no escribe en disco) y permite forzar la apariencia.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --demo --light
./build/Pauta.app/Contents/MacOS/Pauta --demo --dark --view 3
```

`--view 1…6` elige la lista de arranque, en el orden de la barra lateral.
Combinado con `--dump` inspecciona la maqueta en vez de los datos reales.

## Listas

| Lista | Qué contiene |
|---|---|
| Bandeja | Sin fecha, sin proyecto y sin aparcar: lo que aún no has decidido |
| Hoy | Planificadas para hoy o antes. Una tarea vencida sigue apareciendo aquí |
| Próximamente | Planificadas para más adelante, **agrupadas por día** |
| Cualquier momento | Lo que se puede hacer ya: Hoy más las tareas de proyecto sin fecha. La bandeja queda fuera: lo que hay allí aún está sin decidir |
| Algún día | Aparcadas a propósito, sin fecha |
| Registro | Completadas, lo más reciente primero |

«Sin fecha» y «Algún día» son estados distintos: el primero significa «todavía
no lo he decidido» y deja la tarea en la bandeja; el segundo, «lo quiero hacer,
pero no ahora». Por eso ponerle fecha a una tarea aparcada la saca de «Algún
día» — estar aparcada y con fecha a la vez sería contradictorio.

## Cómo se guardan los datos

Un único JSON legible, con escritura atómica:

```
~/Library/Application Support/Pauta/data.json
```

Copiarlo es la copia de seguridad; borrarlo deja la app a cero.

Las tareas y los proyectos se leen con un `init(from:)` escrito a mano que usa
`decodeIfPresent` para todo. No es un capricho: el `Codable` sintetizado de
Swift usa `decode` para las propiedades no opcionales e **ignora sus valores por
defecto**, así que añadir un campo nuevo haría fallar la lectura de los archivos
ya guardados con un `keyNotFound`. Con el decodificador tolerante, los campos que
se añadan en el futuro no rompen los datos existentes. Para ver el
estado guardado sin abrir la interfaz:

```bash
./build/Pauta.app/Contents/MacOS/Pauta --dump
```

La app se llamó **Cosas** antes de llamarse Pauta. Al arrancar, si encuentra
datos en `~/Library/Application Support/Cosas/` y la carpeta nueva está vacía,
los copia. El archivo antiguo se deja como respaldo: cuando compruebes que todo
está en su sitio, puedes borrar esa carpeta.

```bash
rm -rf ~/Library/Application\ Support/Cosas
```

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

- Áreas que agrupen proyectos
- Tareas repetitivas y fechas límite
- Listas de comprobación y etiquetas (y la elección al pegar varias líneas)
- Arrastrar para reordenar
- Sincronización entre dispositivos
- Widget y app de iOS — necesitan proyecto de Xcode y cuenta de desarrollador;
  `PautaCore` ya está extraído para ese salto
- Renombrar los módulos Swift si algún día cambia el nombre del producto
