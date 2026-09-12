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

Esto **no es el puente con el Mac**, aunque naciera para serlo. De eso se encarga
ahora [la carpeta compartida](#el-puente-con-el-mac), que cruza fechas,
proyectos y borrados en los dos sentidos; Recordatorios solo trae títulos y solo
hacia dentro.

Lo que sigue siendo, y hoy no sustituye nada, es **la captura por voz**: Pauta no
tiene atajo propio de Siri, así que todo lo que le dictas —desde la muñeca, en el
coche, con el teléfono bloqueado— entra por aquí o no entra.

## Lo que el teléfono todavía no puede

- **Sincronizar.** En iOS la app va en sandbox y no puede entrar en la carpeta de
  iCloud Drive por ruta, que es como lo hace el Mac. Ahí hace falta el contenedor
  de ubicuidad, y **eso lo cierra la cuenta**. No es una suposición: se le pidió
  el perfil a Apple y contestó que no.

  ```
  Cannot create a Mac App Development provisioning profile for "dev.jadrdev.pauta".
  Personal development teams … do not support the iCloud capability.
  ```

  Que el **grupo de aplicaciones** del widget sí funcionara —y que el perfil dure
  un año— hizo pensar que la cuenta era de pago y que iCloud también entraría.
  Era una deducción, y era falsa: los grupos sí, iCloud no.

  Así que `Store.iCloudRoot` sigue siendo `nil` en iOS y el teléfono guarda en la
  carpeta del grupo: funciona, pero solo. El puente real entre los dos sigue
  siendo [Recordatorios](../README.md#captura-desde-recordatorios), que sincroniza
  gratis.

  Lo que sí hay, sin pagar nada, es **el puente**: elegir la carpeta del Mac una
  vez en el selector del sistema. Está contado abajo.
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

De esta cuenta se sabe, medido: el perfil que Apple emite **dura un año** y
admite **grupos de aplicaciones**, que es lo que necesita el widget. Y se sabe
también lo que no: es un **equipo personal**, y con esos Apple no emite perfiles
con iCloud. Las dos cosas a la vez, por raro que suene — de ahí que deducir «si
admite grupos, es de pago» saliera mal.

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

**El del reloj es el tercero**, y no una copia del de iOS: ahí la máscara es un
**círculo**, y un círculo come bastante más que el redondeo de iOS. Con el arte
del iPhone puesto bajo la máscara redonda, el monograma roza el borde por los
lados — comprobado poniéndole la máscara a mano antes de decidir el tamaño—, así
que va más pequeño: 0,46 del lienzo frente a 0,52. `python3 tools/make-icon.py
reloj`.

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

El Mac tiene el suyo desde después, y **no comparte con este ni el código de la
vista ni la forma de leer los datos**: allí la extensión va en sandbox y los
datos están en iCloud Drive, así que lee una instantánea que la app le deja
escrita. Está contado en el [README](../README.md#el-widget).

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

### El círculo tacha

Mirar la lista y no poder tachar lo que acabas de hacer es la mitad del gesto,
así que el círculo **es un botón**: completa la tarea sin abrir la app. En un
widget, un botón es un `AppIntent`, y el suyo hace una sola cosa.

Y **no reimplementa completar**: abre el almacén de verdad y llama a
`toggleComplete`. Es lo que sabe que una repetitiva pare la siguiente, que
descompletar retire a la sucesora si nadie la tocó y que el aplazamiento se
borre. Tocar `isCompleted` a mano desde aquí cortaría una serie diaria desde la
pantalla de inicio sin que nadie se enterara hasta echar de menos la tarea de
mañana. Hay tres pruebas que clavan justo eso —dos almacenes sobre una carpeta,
uno escribe y el otro lo ve— porque es donde esto se rompería.

**Lo que no hace es borrar.** Eliminar es de las que no se vuelve, y un widget es
un sitio donde se pulsa sin mirar.

Para dibujar, en cambio, no usa `Store`: `Vistazo.leer` abre la carpeta y ya. El
almacén crea carpetas, adopta datos viejos, normaliza posiciones y limpia
lápidas, y eso no tiene por qué pasar cada vez que el sistema pinta un widget.

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

### La ficha de una tarea

Título, notas, cuándo, la hora y **si se repite**. Sin fecha límite y sin
etiquetas: eso se configura una vez sentado, y ofrecerlo todo en una hoja de
teléfono la convierte en un formulario que nadie rellena.

La repetición estaba fuera por esa misma regla, y era **la excepción**: «esto es
todos los días» no se decide sentado delante del Mac, se decide en el momento en
que te das cuenta —tomando la pastilla, regando, estirando— y ese momento pasa
con el teléfono en la mano. Y cabe en una fila, que es lo que la separa de un
formulario. El motor ya estaba entero en el núcleo desde el Mac: al completar
una repetitiva nace la siguiente, heredando hora, margen, etiquetas y pasos, y
poniéndose al día si venía atrasada.

Lo que no sube es **hasta cuándo**. «Cada día hasta el 15 de octubre» sí es una
decisión de sentarse. Si el Mac le puso un fin, el teléfono lo dice —callarlo
haría parecer eterna una serie que caduca— pero no lo cambia.

En la lista, una repetitiva lleva **solo la flecha** de repetición, como en el
Mac: poner «Cada día» al lado del título gasta media fila en algo que ya se sabe
en cuanto se reconoce el icono.

## El puente con el Mac

En iOS una app solo entra donde le dejan, y lo que le deja entrar en una carpeta
de iCloud Drive es que **la elijas tú** en el selector del sistema. Se elige una
vez la carpeta `Pauta` de iCloud Drive, y a partir de ahí el teléfono cruza sus
tareas con las del Mac.

Se ofrece en dos sitios. Siempre en `Más ▸ Ajustes ▸ La carpeta del Mac`; y
además como **última fila de la tarjeta de bienvenida**, debajo del vacío de
`Hoy`, mientras no haya ni una tarea apuntada. Estaba solo en los ajustes y eso
eran tres toques y una pantalla que únicamente abres si ya sospechas que existe:
quien llegaba al teléfono con el Mac lleno de tareas veía una lista vacía y
ningún camino.

Ahí va **dicho como pregunta** —«¿Ya usas Pauta en el Mac?»— y no como una
instrucción. Quien llega nuevo de verdad la lee, ve que no va con él y sigue;
«conecta tu Mac» le haría creer que le falta un paso que no existe.

Y se ofrece **solo mientras no hay nada apuntado**, que es la condición que hace
que esto no se convierta en un mueble. A un permiso se le contesta que sí o que
no y desaparece; a esto no hay forma de contestarle «no tengo Mac». Atada al
estreno se resuelve sola para los dos casos: quien viene del Mac elige la
carpeta, y quien empieza de cero apunta su primera tarea y la fila se va. Que
además es el único momento en que la oferta significa algo — traer tus tareas se
ofrece cuando no hay ninguna.

**No apunta el almacén a esa carpeta**, y esa es la decisión que importa. La
carpeta puede no estar —el teléfono sin red, el permiso caducado, los archivos
todavía en la nube— y un almacén apuntando ahí dejaría la app sin datos en vez de
funcionar sola. Cada lado guarda lo suyo y
[`Puente`](../Sources/PautaCore/Puente.swift) los cruza.

La regla no es nueva: **gana la versión modificada más recientemente**, archivo a
archivo, que es la misma que usa la sincronización del Mac. De ahí sale que dos
aparatos tocando tareas distintas no se pisen nunca, y que un borrado viaje —una
lápida es una versión más—. Los marcadores `.icloud` de lo que iCloud no ha
bajado se cuentan y **no se copian**: copiar uno sería poner la nada encima de
una tarea de verdad.

Se cruza **al volver del fondo** —entre dejar el teléfono y volver a cogerlo es
cuando se ha estado delante del Mac— y a mano, con un botón que dice qué se
movió: «2 del Mac · 11 al Mac». Si no hay carpeta elegida, no hace nada y la app
sigue igual.

### El marcador se puede romper, y se dice

Lo que se guarda de tu elección no es la ruta: una ruta no da permiso. Es un
**marcador** que el sistema sabe volver a convertir en una carpeta con permiso.
Si mueves o renombras esa carpeta, deja de resolver — y una sincronización que se
detiene en silencio es peor que no tenerla. Así que
[`CarpetaElegida`](../Sources/PautaCore/CarpetaElegida.swift) guarda que caducó,
y los ajustes lo dicen en rojo y piden elegirla otra vez.

## Apuntar con la voz

*«Oye Siri, apuntar en Pauta»*, y lo que digas entra en la bandeja. Sin abrir la
app: apuntar algo es lo que haces **mientras** estás en otra cosa, y si te sacara
de donde estás no serviría para eso.

Es un `AppIntent`, así que además sale en **Atajos**, en la pantalla bloqueada y
en el botón de acción. Cuatro formas de pedirlo —*apuntar en*, *apunta en*,
*añadir a*, *nueva tarea en*—, porque nadie recuerda la frase exacta: si solo
valiera una, el atajo existiría para quien leyó esta página.

Vive en la app y no en el widget. El intent del widget es un botón de ese widget
—lleva un identificador crudo dentro y no aparece en Atajos—; este es una acción
de la app y tiene que poder encontrarse.

**No reimplementa apuntar**: usa `addItems(from:)`, el mismo que ya sabe partir
varias líneas, quitar viñetas y descartar lo que queda en blanco. Un dictado es
una línea, pero un atajo puede traer un texto entero, y ahí hacer una tarea con
tres renglones dentro sería peor que hacer tres. Un dictado que no dice nada no
crea una tarea vacía: se dice en voz alta, porque contestar «hecho» sin haber
hecho nada es la forma más rápida de que dejes de fiarte.

Y si la app está delante, lo apuntado aparece **ya**. El intent escribe en la
carpeta por su cuenta, así que avisa, y la app recarga. Sin eso, dictar con Pauta
abierta no cambiaría nada en pantalla hasta salir y volver — justo cuando parece
que se perdió.

### Qué queda de Recordatorios

La captura por [Recordatorios](../README.md#captura-desde-recordatorios) sigue,
y ya no es la única puerta. Lo que este atajo **no** cubre todavía es dictar
desde el **reloj**: los App Intents del teléfono no llegan a la muñeca por su
cuenta, y ahí Siri sigue entrando por Recordatorios. Hasta que el reloj tenga el
suyo, esa es la razón que queda para mantenerlo.

## El reloj

De **solo lectura**, y a propósito. Las dos cosas que una muñeca hace mejor que
un teléfono ya funcionaban sin app: los avisos que programa Pauta en el iPhone
los reenvía el sistema al reloj —con su botón de completar y su aplazar—, y a
Siri se le puede dictar una tarea desde ahí, que entra por
[Recordatorios](../README.md#captura-desde-recordatorios). Lo que faltaba era el
vistazo: levantar la muñeca y saber cuántas quedan.

Así que el reloj **no tiene datos**. Recibe del teléfono el mismo
[`Vistazo`](../Sources/PautaCore/Vistazo.swift) que dibuja el widget —lo que cabe
en un golpe de vista, ya calculado y ordenado por el núcleo— y lo enseña. Sin
almacén, sin cruces y sin nada que se pueda perder ahí.

Viaja en el **contexto de aplicación** de WatchConnectivity y no en mensajes: el
contexto es «lo último que se sabe», lo guarda el sistema y está ahí al levantar
la muñeca aunque el teléfono esté en otra habitación. Un mensaje exige a los dos
despiertos a la vez, que es justo lo que no pasa entonces.

Y distingue **«no hay nada» de «no sé nada»**: con el vistazo recibido y vacío
dice «Nada para hoy»; sin recibir nada dice «Abre Pauta en el iPhone». En un
reloj esos dos mensajes son muy distintos y confundirlos sería mentir.

### Tachar desde la muñeca

Lo único que va en el otro sentido. El círculo de cada tarea es un botón, y
ocupa más de lo que se ve —treinta puntos por catorce de dibujo—: en un reloj el
dedo tapa lo que va a pulsar, y un blanco del tamaño del círculo se falla. El
resto de la fila no hace nada al tocarlo; aquí no hay ficha que abrir, y una
pulsación que a veces tacha y a veces no es peor que una que nunca lo hace.

**El reloj no tacha: lo pide.** Quien tiene los datos es el teléfono, así que lo
que viaja es una orden —`completar`, con el identificador de la tarea— y la
confirmación llega con el vistazo siguiente, que ya no la trae. Mientras tanto
la tarea se ve tachada y en gris: sin eso se quedaría igual el segundo que tarda
el viaje, y se pulsaría otra vez pensando que no se enteró.

**Dice qué hacer, no «cambia esto».** La entrega puede repetirse —el sistema
reintenta cuando los dos aparatos vuelven a verse— y un `toggle` repetido
descompletaría justo lo que acabas de tachar. Por eso el teléfono usa
`Store.completar(_:)`, que marca y no alterna: obedecer dos veces la misma orden
no deshace la primera, y una orden para algo que ya no existe —borrado mientras
viajaba— no es un error, simplemente no hace nada.

**Dos caminos para mandarla**, y los dos hacen falta:

- Con el teléfono al alcance, **mensaje**: llega en el acto y lo ves tachado
  antes de bajar el brazo.
- Sin alcance —que es justo la vez que el reloj sirve para algo—, **cola**
  (`transferUserInfo`): se guarda, sobrevive a que se cierre la app y se entrega
  cuando vuelvan a verse.

El mensaje puede fallar aunque el teléfono pareciera alcanzable, porque entre
mirarlo y mandarlo pasa un instante. Ese fallo no se cuenta a nadie: se mete en
la cola y se acabó. Lo que no puede pasar es que una orden se pierda en silencio.

En el teléfono, quien obedece se instala desde la vista, que es donde vive el
almacén — el enlace no guarda ninguno a propósito: un segundo almacén en el
mismo proceso escribiendo los mismos archivos es exactamente el problema que no
se quiere tener. Y como una orden puede llegar antes de que la vista esté
montada, lo que llegue pronto espera en una cola y se atiende al instalarse.

> **Del simulador:** las órdenes en cola del reloj al teléfono **no se entregan**
> ahí. El camino del mensaje sí, y por él se comprobó la vuelta entera —la tarea
> quedó marcada en el teléfono y desapareció del reloj—. La cola queda
> verificada por su lado probado: el mismo sobre, la misma orden y el mismo
> `completar` que no alterna.

### La complicación

En la esfera, sin abrir nada. Cuatro formas del mismo dato, que es lo que cambia
de un sitio a otro de la esfera:

| Sitio | Qué enseña |
|---|---|
| Círculo | La cuenta y `HOY`, con un aro naranja si hay algo atrasado |
| Esquina | La cuenta, con el renglón curvado alrededor |
| En línea | `5 para hoy · 2 atrasadas`, al lado de la hora |
| Rectángulo | El titular, lo atrasado y la primera tarea con su hora |

Sin color propio: en una esfera manda el color que haya elegido quien la lleva,
y una complicación que se pinta a su gusto se ve como un parche. Lo único que se
permite es marcar lo atrasado, porque es el dato que cambia lo que haces con el
día. Y el aro solo aparece cuando hay algo arrastrándose: si se viera siempre,
dejaría de decir nada.

**De dónde saca los datos.** Una complicación es **otro proceso** y no comparte
memoria con la app del reloj, así que no puede preguntarle qué recibió. Lo que
hay entre las dos es el contenedor del **grupo de aplicaciones**: la app del
reloj escribe ahí el vistazo en cuanto llega del teléfono y avisa a WidgetKit;
la complicación lo lee. Es el mismo arreglo que en el Mac y por el mismo motivo,
con el mismo precio: es una copia y **envejece**.

Por eso lo guardado lleva su día dentro y aquí se comprueba antes de dibujar. Si
no es de hoy, el círculo dice `—` y el rectángulo «Abre Pauta en el reloj», en
vez de enseñar la cuenta de ayer. Una esfera se mira de reojo y nadie la
comprueba: equivocarse ahí es peor que callarse. Esa regla —`Vistazo.deHoy`—
vive en el núcleo y la usan la complicación y el widget del Mac, que hacen lo
mismo; escrita dos veces sería cuestión de tiempo que una se quedara atrás.

**Cuándo se actualiza.** Cuando la app del reloj recibe algo del teléfono: al
abrirla, y cuando el sistema la despierta para entregarle el contexto. No hay
forma de que la complicación hable con el teléfono por su cuenta, así que el
camino sigue siendo el mismo: iPhone → app del reloj → carpeta del grupo →
esfera.

### Del núcleo, lo que en un reloj puede existir

`PautaCoreWatch` compila las mismas fuentes menos tres:
[`RemindersInbox`](../Sources/PautaCore/RemindersInbox.swift),
`PuestaAPunto` y `Agenda`. watchOS **prohíbe** escribir recordatorios —el
compilador lo dice con `__WATCHOS_PROHIBITED`— y allí no hay pantalla de permisos
ni eventos de calendario que enseñar. Se excluyen los archivos en vez de repartir
`#if` por el núcleo: si algún día el reloj necesita una de esas piezas, el
compilador dirá que no está, que es lo que se quiere — un error, no una
divergencia silenciosa. `Captured` se mudó a `Models` justo por esto: es un
modelo del almacén, no parte de Recordatorios.

### Lo que costó, para que no se repita

Cuatro intentos, y cada uno lo dijo el sistema en su registro:

1. **«counterpart app not installed».** La app del reloj tiene que ir **dentro**
   del paquete del teléfono, en `Watch/`. Instalada por su cuenta en el reloj, el
   teléfono no la reconoce como su pareja y el vistazo no sale.
2. **La sesión se activa antes de saber que el reloj tiene la app.** El registro
   enseña `appInstalled: NO` al activarse y `YES` dos segundos después: el primer
   vistazo salía en medio y moría con `WCErrorCodeWatchAppNotInstalled`. Se
   guarda el último y se reintenta al activarse, al cambiar el estado del reloj y
   al volver a estar cerca.
3. **El bloque que publicaba no llegaba a ejecutarse.** Colgaba de un
   `task(id: store.items)` con un segundo de espera, y al arrancar hay una ráfaga
   de cambios —recargar, cruzar con el Mac, importar— que lo cancelaba una y otra
   vez. Cero recargas del widget en un arranque entero, comprobado en el
   registro. Ahora se avisa a fuera también al terminar el arranque.
4. Y `simctl install` con **ruta relativa** dice que instala y no instala.

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
deslizando, una ficha por tarea para cambiarle el día o **hacerla repetitiva**,
y **los avisos** — el
repaso del día se programó solo en el simulador y pidió permiso, que es la señal
de que el núcleo entero está vivo ahí.

---

[← Volver al README](../README.md)
