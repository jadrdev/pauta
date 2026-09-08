# La app de iOS

Existe, arranca y se instala en un iPhone. Comparte con el Mac **todo el núcleo y
ninguna vista**:

```
PautaCore    3.066 líneas   modelo, almacén, consultas, avisos, sincronización
Pauta        3.853 líneas   la interfaz de macOS
PautaIOS     1.051 líneas   la interfaz del teléfono
```

Ninguna vista compartida es una decisión, no una pereza. Un teléfono no se maneja
como un Mac: no cabe la barra lateral, no hay clic derecho y la mano tapa media
pantalla. Las listas son las mismas —las de verdad, calculadas por el mismo
código—; la forma de andar por ellas, no.

**Pestañas abajo** —Hoy, Próximamente, Bandeja y Más— y no una tira de fichas
arriba. Abajo llega el pulgar, es un toque para cambiar, y es lo que iOS entiende
por cambiar de sección: una fila de fichas arriba es un patrón de web y en un
teléfono se lee como un navegador. Cuatro y no siete, porque una barra de siete
iconos no se lee, se adivina: las tres de diario tienen sitio fijo y el resto
—listas de fondo, proyectos, áreas, etiquetas— vive en «Más», donde sí se entra
y se vuelve.

**Título grande** por pantalla, con la cuenta en versalitas debajo, como en el
Mac. Sin título, la lista activa se distinguía por un fondo verde pálido y sabías
dónde estabas por deducción.

**Apuntar va en un botón flotante**, no en una franja fija. El campo se usa a
ráfagas y una franja permanente cobra sitio a la lista todo el rato; el botón lo
encuentra el pulgar sin mirar y no tapa nada mientras no se usa. Al pulsarlo
aparece el campo sobre el teclado —como franja del área segura, que si fuera una
superposición se quedaría debajo de la barra de pestañas— y las pestañas se
esconden: con el teclado abierto no se cambia de sección. **No se cierra al
guardar**: cuenta lo apuntado —«3 apuntadas · sigue escribiendo»— porque vaciar
la cabeza de tres cosas seguidas es cuando de verdad hace falta.

**La fila recupera la densidad del Mac**, en dos alturas: a la derecha lo del
reloj —hora con su campana si hay margen, luna del aplazamiento, retraso, fecha
límite, duración— y debajo del título el contexto —proyecto, etiquetas, pasos—.
Todo en una línea sería una fila que no se puede leer de reojo. La duración va
**sin icono**: «45 min» se entiende solo, y a tamaño de teléfono el cronómetro no
se distinguía del reloj del retraso, que es lo único que debe leerse como un
reloj.

Deslizar una fila da eliminar a la izquierda y programar para hoy a la derecha.

Lo que sí se comparte del diseño son los colores, y por eso salieron del tema de
macOS a [`Paleta`](../Sources/PautaCore/Paleta.swift) en el núcleo: números en
crudo, que cada plataforma convierte a su manera —`NSColor` con apariencias,
`UIColor` con rasgos—. Con dos tablas, la primera corrección de contraste dejaría
una interfaz atrás sin que nadie se enterase.

```bash
./tools/ios.sh              # compila e instala en el simulador
./tools/ios.sh "iPhone Air" # en otro modelo
./tools/iphone.sh           # en un iPhone conectado por cable
```

Sin proyecto de Xcode, igual que el Mac: se compila con `swiftc` y el `.app` se
monta a mano. **Para el simulador eso basta y no hay que firmar nada**, que es lo
que permite tener algo instalable hoy sin cuenta de desarrollador. El guion es
además el único sitio que compila estas fuentes: no están en `Package.swift`,
porque un objetivo que importa UIKit rompería `swift build` en el Mac.

## Lo que dicta Siri llega aquí

La [captura desde Recordatorios](../README.md#captura-desde-recordatorios)
funciona igual que en el Mac, y en un teléfono es donde tiene sentido de verdad:
importa al abrir la app, al volver del fondo y **en cuanto cambia la lista**, así
que lo que le dictes a Siri aparece en la bandeja sin tocar nada.

No cambia de pestaña cuando entra algo. Mover la pantalla debajo del dedo es peor
que no avisar; la cuenta de la bandeja ya lo dice.

Mientras la carpeta de iCloud siga fuera de alcance, esto es **el único puente
que hay entre el teléfono y el Mac**, y funciona sin pagar nada.

## Lo que el teléfono todavía no puede

- **Sincronizar.** En iOS la app va en sandbox y no puede entrar en la carpeta de
  iCloud Drive por ruta, que es como lo hace el Mac. Ahí hace falta el contenedor
  de ubicuidad, con entitlements y **cuenta de desarrollador de pago**. Sin eso
  `Store.iCloudRoot` es `nil` por construcción y el teléfono guarda en su propia
  carpeta: funciona, pero solo. Hasta entonces el puente real entre los dos es
  [Recordatorios](../README.md#captura-desde-recordatorios), que sí sincroniza gratis.
- **Enterarse de cambios de fuera.** `FolderWatcher` usa FSEvents, que no existe
  en iOS, así que se compila fuera. En su lugar recarga al volver del fondo. El
  equivalente para una carpeta sincronizada sería `NSMetadataQuery`, y hace falta
  el día que haya iCloud.

## En un iPhone de verdad

```bash
./tools/iphone.sh
```

Compila, firma, instala y abre. Hacen falta tres cosas que el simulador no pide:

1. **El modo de desarrollador** activado en el teléfono —Ajustes ▸ Privacidad y
   seguridad ▸ Modo de desarrollador—, que lo enciende su dueño y reinicia el
   aparato.
2. **Una cuenta registrada en Xcode.** El perfil de aprovisionamiento lo crea
   Xcode contra ella; el guion pasa `-allowProvisioningUpdates` para que lo haga
   sin abrir la interfaz.
3. **Un `.xcodeproj`**, porque `xcodebuild` es quien sabe firmar. Se declara en
   [`project.yml`](../project.yml) y lo genera XcodeGen (`brew install xcodegen`):
   un pbxproj son miles de líneas generadas que se llenan de conflictos y que
   nadie lee, así que no se guarda en el repositorio — veinte líneas de YAML sí.

Con un equipo **gratuito el perfil dura siete días**: al octavo la app deja de
abrirse y hay que volver a ejecutar el guion. Sin límite, con la cuenta de pago.

El UDID no está escrito en el guion: lo busca. Un identificador pegado a mano
caduca en cuanto cambias de teléfono o de cable, y lo hace en silencio. El filtro
exige además que el dispositivo sea `physical`, porque para `devicectl` los
simuladores también son iPhone y aparecen conectados — sin eso, instala en el
simulador y el error habla de rutas que no existen.

En el proyecto el núcleo va como **objetivo propio** y no como dependencia del
paquete: dependiendo del paquete, Xcode intenta compilar todos sus objetivos
para iOS —incluido el ejecutable de macOS con su AppKit, su Carbon y su
ServiceManagement— y no hay forma de decirle que ese es solo del Mac. Son los
mismos archivos; cambia quién los compila.

El icono es el mismo monograma del Mac con otra lámina: **a sangre, sin margen ni
esquinas redondeadas**. La máscara la pone iOS, y la lámina del Mac encima se
vería como un icono metido en un marco con un borde muerto alrededor. El
monograma va algo más pequeño en proporción, porque el redondeo de iOS come
esquina y lo que en una lámina plana parece holgado ahí queda pegado al filo. Se
genera con `python3 tools/make-icon.py ios`, del mismo arte y en el mismo sitio
que los del Mac, para que no puedan divergir.

Va como catálogo de recursos con **una sola imagen de 1024**: desde Xcode 14 el
sistema deriva los tamaños, y mantener quince a mano era garantizar que alguna se
quedara con el arte viejo. En la ruta del simulador, que no pasa por Xcode, lo
compila `actool` y las claves del plist las escribe la propia herramienta — en
iOS el icono no es un PNG suelto en el paquete.

**Los eventos del calendario también salen en Hoy**, igual que en el Mac y con la
misma mezcla —`Agenda.filas`, en el núcleo—: todo el día arriba, luego lo que
tiene hora, sea evento o tarea, y al final lo que no la tiene. La fila de un
evento lleva **barra de color en vez de casilla**: un evento no se completa,
ocurre, y darle algo redondo que parezca pulsable sería prometer un gesto que no
existe. Lo que ya pasó se apaga, y no admite deslizar: no es tuyo, se lee y
punto. El permiso se pide desde la propia lista de Hoy, con la misma invitación
que el Mac, y solo mientras no se haya contestado.

## Los ajustes del teléfono

En `Más ▸ Ajustes`, y son **tres de los cinco del Mac**: el repaso del día, el
margen del aviso y cuánto aplaza. Los otros dos no existen en un teléfono
—arrancar al iniciar sesión y la cuenta atrás de la barra de menús— y el atajo
global tampoco. Se guardan en el aparato y no viajan: la hora a la que te
levantas mirando el móvil no tiene por qué ser la del Mac.

Y llevan dos cosas que en el Mac viven en otro sitio, porque en un teléfono no
hay menú de la app donde ponerlas y son justo lo que se viene a buscar aquí:

- **Los permisos** —avisos y calendario—, que en el Mac están en la ayuda. Sin
  preguntar se piden desde ahí; denegados, se enlaza a los ajustes del sistema,
  que es el único sitio donde esa decisión se cambia.
- **El «Acerca de»**: versión, enlaces, autoría, y **dónde están los datos**. Con
  la parte incómoda dicha: en este teléfono, y todavía sin sincronizar con el
  Mac. Es la pregunta que se hace cualquiera que tenga las dos apps, y callarla
  haría parecer que está roto lo que solo está pendiente.

Lo que sí hace ya: las cinco listas con sus cuentas, apuntar, completar, borrar
deslizando, una ficha por tarea para cambiarle el día, y **los avisos** — el
repaso del día se programó solo en el simulador y pidió permiso, que es la señal
de que el núcleo entero está vivo ahí.

---

[← Volver al README](../README.md)
