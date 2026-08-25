# Pauta

Gestor de tareas para macOS. SwiftUI nativo, datos en local, sin suscripción.

## Identidad

Monograma «P» con check verde, sans geométrica, verde de marca sobre casi negro
azulado.

- **Verde `#10E888`** como acento único. Marca la lista activa, los contadores y
  la casilla completada.
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
| `⌘1` / `⌘2` / `⌘3` | Bandeja / Hoy / Registro |

Clic en una tarea para desplegarla y editar notas, fecha o proyecto.
Clic derecho para programarla o eliminarla.

## Modo maqueta

Para revisar el diseño sin tocar tus datos reales: arranca con tareas de muestra
en memoria (no escribe en disco) y permite forzar la apariencia.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --demo --light
./build/Pauta.app/Contents/MacOS/Pauta --demo --dark
```

## Cómo se guardan los datos

Un único JSON legible, con escritura atómica:

```
~/Library/Application Support/Pauta/data.json
```

Copiarlo es la copia de seguridad; borrarlo deja la app a cero. Para ver el
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
Sources/Pauta/
  PautaApp.swift          punto de entrada, menús y atajos
  Models/Models.swift     Item, Project, Perspective
  Models/Store.swift      estado + persistencia + consultas
  Views/Theme.swift       paleta, tipografía y filetes
  Views/SidebarView.swift barra lateral
  Views/ItemListView.swift lista y cabecera
  Views/ItemRowView.swift fila, casilla y editor desplegado (Liquid Glass)
```

## Qué falta (siguiente iteración)

- Perspectivas `Próximamente`, `Cualquier momento` y `Algún día`
- Áreas que agrupen proyectos
- Tareas repetitivas y fechas límite
- Listas de comprobación y etiquetas
- Arrastrar para reordenar
- Sincronización entre dispositivos
- Icono de app propio (ahora usa el genérico del sistema)
- Renombrar el módulo Swift si algún día cambia el nombre del producto
