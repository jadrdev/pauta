# La app de iOS

Existe, arranca y se instala en un iPhone. Comparte con el Mac **todo el núcleo y
ninguna vista**:

```
PautaCore    3.547 líneas   modelo, almacén, consultas, avisos, sincronización
Pauta        4.177 líneas   la interfaz de macOS
PautaIOS     1.424 líneas   la interfaz del teléfono
PautaWidget    266 líneas   el widget, que solo dibuja
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

Las dos rutas pasan por el mismo proyecto de Xcode y el mismo `xcodebuild`, y
cambian solo el destino. **Para el simulador sigue sin hacer falta firma de
verdad**; para un teléfono, sí.

El simulador se montaba antes a mano —`swiftc` y un `.app` armado a pulso, sin
proyecto—, y era una buena idea mientras la app era un solo binario. **El widget
acabó con eso**: una extensión no es un binario más dentro del paquete, es otro
paquete con su identificador, sus permisos y su punto de extensión, embebido en
`PlugIns/` y firmado aparte. Montar eso a pulso es reimplementar a Xcode, y un
paquete mal armado no falla al compilar: falla al **no aparecer en la galería de
widgets**, que es el peor error posible, el que no dice nada.

Estas fuentes no están en `Package.swift`: un objetivo que importa UIKit
rompería `swift build` en el Mac. Quien las compila es el proyecto.

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
  de ubicuidad, con sus entitlements. Eso se daba por imposible por la cuenta, y
  **no lo es**: la cuenta admite capacidades de este tipo —lo demostró el grupo
  de aplicaciones del widget—. Lo que queda es el trabajo, no el permiso.
  `Store.iCloudRoot` sigue siendo `nil` en iOS por construcción y el teléfono
  guarda en la carpeta del grupo: funciona, pero solo. Mientras tanto el puente
  real entre los dos es
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

**Cuánto dura el perfil depende de la cuenta**: con un equipo gratuito, siete
días —al octavo la app deja de abrirse y hay que volver a ejecutar el guion—; con
membresía de pago, un año. El guion no lo afirma: lee la fecha del perfil que
acaba de quedar dentro del paquete y la dice al terminar. Un aviso con una fecha
supuesta es exactamente cómo se acaba creyendo que la app caduca el martes.

Esta cuenta es de pago, y se comprobó midiéndolo en vez de recordándolo: el
perfil que Apple emitió para este `.app` **caduca en un año** y admite grupos de
aplicaciones, que es lo que necesita el widget y lo que un equipo gratuito no
da.

El UDID no está escrito en el guion: lo busca por cable y emparejado. Un identificador pegado a mano
caduca en cuanto cambias de teléfono o de cable, y lo hace en silencio. El filtro
exige además que el dispositivo sea `physical`, porque para `devicectl` los
simuladores también son iPhone y aparecen conectados — sin eso, instala en el
simulador y el error habla de rutas que no existen.

Lo que decide es que esté **emparejado**, y nada más. Esta es la tercera versión
del filtro; las dos anteriores intentaban adivinar si el teléfono estaba
alcanzable leyendo la foto que da `devicectl`, y las dos se equivocaron:

| Señal | Por qué no basta |
|---|---|
| `tunnelState == connected` | Es el túnel de depuración: se duerme y solo despierta cuando algo le habla. Por cable suele estar dormido, y el teléfono enchufado se declaraba ausente |
| `transportType == wired` | Por Wi-Fi el mismo teléfono es `localNetwork`, y volvía a declararse ausente con la app en la mano |

Y por red puede estar emparejado, despierto y con el túnel caído **a la vez**.
Ese estado no se puede leer sin intentar hablarle, así que no se lee: se elige el
mejor candidato —cable primero, luego túnel vivo— y **decide el intento de
instalar**, que sabe más y da un error de verdad si no llega. El guion dice a qué
teléfono va y por dónde, para que un fallo así se vea antes y no después.

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
quedara con el arte viejo. Lo compila el propio proyecto —en iOS el icono no es
un PNG suelto en el paquete, sino un catálogo compilado más unas claves en el
plist que escribe la herramienta—.

**Los eventos del calendario también salen en Hoy**, igual que en el Mac y con la
misma mezcla —`Agenda.filas`, en el núcleo—: todo el día arriba, luego lo que
tiene hora, sea evento o tarea, y al final lo que no la tiene. La fila de un
evento lleva **barra de color en vez de casilla**: un evento no se completa,
ocurre, y darle algo redondo que parezca pulsable sería prometer un gesto que no
existe. Lo que ya pasó se apaga, y no admite deslizar: no es tuyo, se lee y
punto. El permiso se pide desde la propia lista de Hoy, con la misma invitación
que el Mac, y solo mientras no se haya contestado.

## El widget

Es la única parte de la app que se ve **sin abrirla**, y por eso existe: apuntar
algo sirve de poco si para acordarse de lo apuntado hay que acordarse de abrir la
app.

Enseña el día: «3 para hoy», «2 atrasadas» aparte y en rojo —el dato que cambia
lo que haces con la mañana—, las primeras tareas con su hora, y abajo lo que
queda sin decidir en la bandeja. Lo que no cabe **se dice**: «+3 más». Un widget
que enseña tres de nueve y no lo confiesa está mintiendo.

Cuatro tamaños: pequeño y mediano en la pantalla de inicio, grande, y una línea
para la pantalla de bloqueo.

**El día vacío es un botón.** Sin nada para hoy, lo único útil que se puede hacer
desde un widget es apuntar lo próximo, así que ahí el widget entero se convierte
en eso: «Apuntar algo», y un toque abre la app con el campo listo y el teclado
arriba.

### Por qué los datos se mudaron de carpeta

Un widget es **otro proceso y otra caja**: no comparte memoria con la app, no
puede preguntarle nada y **no puede leer su carpeta**. Lo único que ven los dos
es el contenedor de un *grupo de aplicaciones*, así que en iOS los datos viven
ahí —`group.dev.jadrdev.pauta`— y no en la carpeta privada de la app.

La mudanza no se programó para esto: el almacén ya sabía adoptar lo que hubiera
en la carpeta anterior —se escribió para el estreno de iCloud en el Mac— y dejó
el origen intacto como respaldo. Comprobado en el simulador que ya tenía datos:
cinco tareas en la carpeta vieja, cinco en la nueva, y las cinco viejas donde
estaban.

En el Mac no cambia nada: allí la app no está en sandbox y sus datos siguen en
iCloud Drive, que es donde tienen que estar.

### Lo que decide qué se ve está en el núcleo

[`Vistazo`](../Sources/PautaCore/Vistazo.swift) —cuántas hay, cuáles caben, en
qué orden, cómo se dice en palabras— con la fecha **por parámetro**. Es lo único
que se puede probar de un widget: en su sitio no hay pantalla que mirar. Diez
tests, y uno de ellos escribe con el almacén y lee con el vistazo, que es
exactamente lo que pasa entre los dos procesos de verdad.

El orden es **el mismo que la lista de Hoy** de la app, no uno propio: dos listas
que dicen ser lo mismo y no coinciden hacen que no te fíes de ninguna.

### Solo lee

El widget no escribe en tus datos, ni siquiera para completar una tarea. Por eso
el círculo de la fila **no es un botón**: está porque es lo que hace que una
lista se lea como una lista de tareas, y uno que pareciera pulsable sin serlo
sería peor que no ponerlo. Tampoco usa `Store`, que crea carpetas, adopta datos
viejos, normaliza posiciones y limpia lápidas — un widget no tiene ningún derecho
a hacer nada de eso. Lee la carpeta y dibuja; lo que no entienda, se lo salta.

Y una carpeta que no existe no es un error: es un teléfono donde la app aún no se
ha abierto, y ahí el widget dice «Nada para hoy».

### Cuándo se refresca

Una entrada, y la siguiente al filo de la **medianoche**. No hay más que
calcular: lo que se enseña no cambia con las horas, cambia cuando cambian las
tareas —y de eso avisa la app en cuanto toca algo, con el mismo segundo de espera
que usa para reprogramar los avisos—. Lo que sí cambia solo es el día: a las doce
lo de hoy pasa a ser atrasado. Un widget que se recargara cada hora gastaría el
presupuesto de recargas del sistema para dibujar lo mismo.

### Los enlaces

Un toque tiene que abrir **su** pantalla, no la última que quedara abierta:

| Dirección | Dónde cae |
|---|---|
| `pauta://hoy` | la pestaña Hoy |
| `pauta://bandeja` | la bandeja |
| `pauta://apuntar` | Hoy, con el campo de apuntar abierto |
| `pauta://tarea/<uuid>` | la ficha de esa tarea |

Se construyen y se leen en [`Enlaces`](../Sources/PautaCore/Enlaces.swift), en el
núcleo y no en cada punta: quien escribe la dirección es un proceso y quien la
interpreta es otro, y una errata en uno de los dos es un toque que no hace nada.
Están probados por las dos puntas. Lo que no se reconoce **no se inventa**: abrir
la app en otra pantalla porque llegó una dirección rara es peor que no abrir
nada.

La ficha de la tarea se abre desde la raíz de las pestañas y no desde dentro de
la lista: así da igual en qué pestaña estuvieras, y si esa tarea ya no existe
—se completó en el Mac, se borró— se aterriza en Hoy sin más.

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
