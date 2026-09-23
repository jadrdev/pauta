<div align="center">

<img src="Resources/icon-mono-preview.png" width="120" alt="Pauta">

<h1>Pauta</h1>

<p><strong>Gestor de tareas para macOS.</strong><br>
Nativo en SwiftUI, sin cuentas, sin suscripción<br>
y con tus datos en tu propia carpeta de iCloud.</p>

<p>
<img src="https://img.shields.io/badge/macOS-14%2B-10E888?style=flat-square&labelColor=0E1114" alt="macOS 14+">
<img src="https://img.shields.io/badge/Swift-6-10E888?style=flat-square&labelColor=0E1114" alt="Swift 6">
<img src="https://img.shields.io/badge/dependencias-ninguna-10E888?style=flat-square&labelColor=0E1114" alt="sin dependencias">
<img src="https://img.shields.io/badge/tus%20datos-en%20tu%20carpeta-10E888?style=flat-square&labelColor=0E1114" alt="tus datos en tu carpeta">
<a href="LICENSE"><img src="https://img.shields.io/badge/c%C3%B3digo-a%20la%20vista-10E888?style=flat-square&labelColor=0E1114" alt="código a la vista, no de código abierto"></a>
</p>

<p>
<a href="docs/ios.md"><strong>La app de iOS</strong></a>&nbsp; ·&nbsp;
<a href="docs/compilar.md"><strong>Compilar y firmar</strong></a>&nbsp; ·&nbsp;
<a href="docs/tecnica.md"><strong>Cómo se guarda y se sincroniza</strong></a>
</p>

<img src="docs/arrastrar-entre-dias.gif" width="760" alt="Arrastrar una tarea de un día a otro en Próximamente">

<p><em>Arrastrar entre días: la fila que señalas dice dos cosas,<br>
la prioridad y el día.</em></p>

<p><sub>Hecho por <a href="https://github.com/jadrdev">@jadrdev</a></sub></p>

</div>

Pauta organiza el trabajo en dos ejes: **cuándo** y **de qué**. Una tarea entra
por la bandeja sin que tengas que decidir nada más que el título. Desde ahí le
pones fecha —y aparece en Hoy o en Próximamente—, la aparcas en Algún día, o la
metes en un proyecto.

Las listas de la barra lateral no son carpetas: son **consultas** sobre ese
estado. Una tarea con fecha de hoy y sin hora que pertenece a un proyecto sale a
la vez en Hoy, en Cualquier momento y en su proyecto, sin duplicarse. Cambiar su
fecha la mueve de lista sola.

## Las listas

| Lista | Qué contiene |
|---|---|
| Bandeja | Sin fecha, sin proyecto y sin aparcar: lo que aún no has decidido |
| Hoy | Planificadas para hoy o antes, más lo que tenga la **fecha límite encima**. Una tarea vencida sigue apareciendo aquí |
| Próximamente | Planificadas para más adelante, **agrupadas por día** |
| Cualquier momento | Lo que se puede hacer **cuando puedas**: lo de Hoy que no tiene hora, más las tareas de proyecto sin fecha. La bandeja queda fuera —lo que hay allí aún está sin decidir— y lo que tiene hora también: a las nueve no es cualquier momento |
| Algún día | Aparcadas a propósito, sin fecha |
| Completadas | Lo hecho, lo más reciente primero |

Los **proyectos** aparecen debajo, cada uno con su cuenta de tareas abiertas.

Una tarea de proyecto sin fecha sale en `Cualquier momento` a propósito: meterla
en un proyecto ya es decidir que se va a hacer, solo falta cuándo.

Y **lo que tiene hora no sale ahí**, aunque sea de hoy. La lista existe para
elegir qué hacer ahora, y una tarea de las nueve no se elige: se hace a las
nueve. Antes entraba todo lo de Hoy, con hora o sin ella, y una repetitiva
diaria a hora fija —la pastilla, el riego— reaparecía cada día en la única lista
que debería estar libre de horarios. Sigue saliendo en `Hoy`, que es donde la
columna del reloj significa algo.

Por lo mismo, **quitarle el día a una tarea le quita la hora**: una hora sin día
no dice cuándo. Ya pasaba al dejarla sin fecha y al aparcarla, y ahora también
al arrastrarla a la bandeja o a `Cualquier momento` — antes se quedaba con una
hora huérfana y desaparecía de la lista donde acababas de soltarla. Fuera de su
propio proyecto, cada tarea lleva el nombre del proyecto —con su emoji— en una
pastilla a la derecha, que es lo que permite distinguir dos tareas que se llamen
igual.

«Sin fecha» y «Algún día» son estados distintos, y esa distinción es el centro
del modelo: el primero significa «todavía no lo he decidido» y deja la tarea en
la bandeja; el segundo, «lo quiero hacer, pero no ahora». Por eso ponerle fecha
a una tarea aparcada la saca de Algún día — estar aparcada y con fecha a la vez
sería contradictorio.

<div align="center">
<img src="docs/proximamente-claro.png" width="820" alt="Próximamente, agrupada por día, en tema claro">
<p><em>La app sigue el tema del sistema.</em></p>
</div>

## Cómo se usa

| Atajo | Acción |
|---|---|
| `⌃Espacio` | [Alta rápida](#alta-rápida) a la bandeja, desde cualquier app |
| `⌘N` | Nueva tarea en la lista actual |
| `⌘⇧N` | Nuevo proyecto |
| `⌘⌥N` | Nueva área |
| `↩` | Guardar y seguir escribiendo otra tarea |
| `esc` | Cancelar la tarea nueva |
| `⌘1` … `⌘6` | Bandeja / Hoy / Próximamente / Cualquier momento / Algún día / Completadas |
| `⌘0` | Volver a la ventana principal si se cerró |
| `⌘?` | Ayuda: los atajos y el estado de los permisos |
| `⌘,` | Ajustes |

Una tarea nueva nace ya encajada en la lista donde la creas: en Hoy sale con la
fecha de hoy, en Próximamente con la de mañana, en Algún día aparcada, y dentro
de un proyecto asignada a él.

Clic en una tarea la despliega para editar título, notas, fecha, repetición y
proyecto; se guarda mientras escribes, sin botón de guardar. El menú de fecha
tiene atajos para hoy, mañana y la semana que viene, y **«Otra fecha…» abre un
calendario** para cualquier día. El calendario es propio y no el `DatePicker`
gráfico del sistema, que traía su caja, su tipografía y su azul, y aquí se veía
diminuto y prestado. Este usa la paleta y los rótulos del resto de la interfaz,
marca hoy con un perfil y el día elegido con relleno, y siempre dibuja seis
semanas para que el panel no encoja al cambiar de mes. Clic derecho abre las acciones
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
- Sobre una tarea **de otro día en `Próximamente`**, además le pone ese día. Esa
  lista está agrupada por fecha, así que la fila que señalas dice dos cosas y no
  una, y cambiar solo la prioridad hacía que el gesto pareciera no hacer nada:
  la tarea se quedaba donde estaba. También se puede soltar sobre el **rótulo del
  día**, que la manda a la cabeza de ese día.
- **Los proyectos también se arrastran entre ellos** para ordenar la barra
  lateral, y **sobre un área** para meterlos en ella. Sobre el rótulo
  `PROYECTOS` vuelven a quedarse sueltos.
- **Las áreas se arrastran entre ellas** para ordenarlas.

Una misma fila recibe cosas distintas, así que la señal cambia según lo que
lleves: **línea de inserción** cuando es reordenar entre iguales, y **la fila
entera encendida** cuando es meter algo dentro. Son gestos que caen en el mismo
sitio y no deben parecer el mismo.

Pasando el cursor por el rótulo `PROYECTOS` aparece **«A–Z»**, que ordena áreas
y proyectos alfabéticamente; también está en el menú de cualquiera de los dos. Es el alfabético del idioma, no el de los códigos: la ñ va tras la n y
los acentos cuentan como su letra. Los proyectos se ordenan **dentro de su
grupo**, que es como se leen. Solo aparece con el cursor encima porque ordenar
es algo que se hace de año en año.

### El «⋯» y el clic secundario

Al pasar el cursor por un proyecto, un área o una etiqueta, el número de la
derecha deja sitio a un **«⋯»** con lo que se puede hacer con ella: eliminar,
mover un proyecto de área, renombrar una etiqueta o quitarla de todas las
tareas. Lo mismo sale con el **clic secundario**, y sale de la misma
definición: un menú escrito dos veces acaba diciendo dos cosas distintas.

Existe porque **esas acciones solo vivían en el botón derecho**. Un gesto que
hay que conocer de antemano no es una función: para quien no lo conoce, eliminar
un proyecto sencillamente no estaba. El menú contextual se queda como lo que
debió ser siempre, un atajo para quien ya lo usa.

El «⋯» no aparece en Bandeja, Hoy y las demás listas fijas: ahí no hay nada que
ofrecer, y un botón que no hace nada es peor que ninguno. Y no se quita de la
vista al abrirse el menú, solo se apaga: al desplegarse, el cursor deja la fila,
y si desapareciera de verdad el menú se cerraría solo justo al ir a elegir.

Las tareas tienen el suyo con el clic secundario: completar, programar para hoy
o para mañana, aplazar, aparcar, quitar la fecha, **mover a** un proyecto y
eliminar. Completar está el primero porque es lo que más se hace y hasta ahora
solo se llegaba por el círculo, que mide dieciséis puntos: la acción más
frecuente era también la que más puntería pedía.

### Áreas

Un área es un cajón de proyectos: «Casa», «Trabajo», «Estudios». Al pincharla
enseña **todo lo pendiente de sus proyectos**, con la pastilla del proyecto en
cada tarea para saber de dónde sale cada una.

Un área **no guarda tareas propias**. Lo que agrupa son proyectos, así que sin
proyecto no habría a qué colgarlas, y una tarea suelta dentro de un área sería
un segundo padre con sus propias reglas en un modelo que ya tiene uno. Por eso
estando en un área no aparece el botón de añadir y `⌘N` crea en la bandeja, que
es donde va lo que aún no está decidido.

Borrar un área **no borra sus proyectos**: los deja sueltos. Agrupar no es
contener, y perder el trabajo de dentro por tirar el cajón sería una pérdida
difícil de deshacer.

El rótulo `PROYECTOS` se muestra aunque no haya ninguno suelto: es el sitio
donde se sueltan para sacarlos de un área, y sin él no habría forma de sacarlos
arrastrando.

La prioridad es **una sola para toda la app**, no una por lista: las listas son
consultas sobre la misma tarea, así que su prioridad es intrínseca y todas la
respetan. En `Próximamente` manda el día, y el orden manual solo ordena dentro de
cada día.

Pegar un texto de varias líneas en el campo de nueva tarea **pregunta qué
quieres**: tantas tareas como líneas, o una sola tarea con el resto como pasos.
Las dos lecturas son razonables y ninguna es obviamente la buena, así que decidir
por ti acertaría la mitad de las veces. En ambos casos se quitan las viñetas
(`*`, `-`, `•`) y la numeración.

### Los eventos del día

<div align="center">
<img src="docs/hoy-oscuro.png" width="820" alt="Hoy, con los eventos del calendario mezclados entre las tareas">
</div>

`Hoy` enseña también **los eventos de tu calendario**, para que sea el día
completo y no solo la lista de tareas: lo que hay que hacer y lo que ya está
comprometido, en el orden en que va a ocurrir. Lo de todo el día enmarca la
jornada y va arriba; después, todo lo que tiene hora —da igual si es un evento o
una tarea— y por último lo que no tiene hora, en su orden manual. Un evento ya
terminado se apaga: sigue siendo parte del día, pero ya no pide nada.

Se leen y no se tocan: sin casilla, sin arrastre y sin editor. La casilla es la
promesa de que algo se puede completar, y un evento no se completa — se pasa. La
franja de color es la del calendario del que viene, que es como se distingue de
un vistazo el trabajo de lo demás.

**Los eventos no entran en el `Store`.** Si entraran, acabarían escritos en la
carpeta como copias del calendario de verdad, y dos copias de lo mismo terminan
discrepando: se edita el evento fuera y aquí queda la versión vieja para
siempre. La fuente es el calendario; esto es lo que se lee de él cada vez, y se
relee solo cuando el sistema avisa de que algo cambió. Tampoco se hace al revés
—escribir las tareas de Pauta como eventos—: duplicaría cada tarea en dos sitios
que se editan por separado y hay que reconciliar.

El permiso se ofrece **una vez**, con una línea discreta en `Hoy`. Si dices que
no, no se vuelve a preguntar desde ahí; queda el comando *Eventos del
calendario…*, que lleva a los ajustes del sistema. Y no se cuentan como tareas:
el rótulo dice «4 EVENTOS · 7 ABIERTAS», porque un evento no es algo que hacer.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --eventos
```

### Varias del mismo proyecto

<div align="center">
<img src="docs/hoy-grupo.png" width="820" alt="Tres tareas de Mudanza agrupadas bajo el proyecto, con el filete a medio entintar">
</div>

Cuando en `Hoy` caen **dos o más tareas del mismo proyecto**, se agrupan bajo él
en vez de repartirse por la lista. Desde dos, no desde una: una sola dentro de
una caja con cabecera son tres líneas para decir lo que decía una, y con el
umbral en uno un día variado se convierte en una lista de títulos con una tarea
debajo de cada uno.

**Se agrupa sin reordenar.** El bloque se coloca donde estaba su primera tarea
pendiente y dentro conserva el orden manual: agrupar parte la lista, no vuelve a
ordenarla. Lo que priorizaste arrastrando tiene que seguir mandando a la mañana
siguiente. Dentro del grupo desaparece la pastilla del proyecto, que ya lo dice
el título de encima — la misma regla que siguen las etiquetas y la lista de un
proyecto.

**Solo se agrupa el tramo sin hora.** Arriba manda el reloj: una reunión a las 10
y una tarea a las 11 salen en ese orden aunque la tarea sea del proyecto del que
hay otras cinco. Meter proyectos ahí se llevaría por delante lo único que ese
tramo dice, que es qué va antes.

#### El filete que se entinta

El filete que separa la cabecera de sus tareas **es** el indicador: se entinta
según despejas el bloque y queda entero al terminarlo. Hace dos trabajos con una
raya —separa y mide— y habla el idioma de la app, que es de papel. Un gráfico de
sectores sería de otra hoja.

Al lado no se dice lo que llevas hecho, sino **lo que queda**: «3 de 5» es
información sobre la mañana que ya pasó, y con lo que se decide si te pones ahora
es con «QUEDAN 2 · 45 MIN». Los minutos salen de las estimaciones que ya llevaban
las tareas, así que son un extra y no un requisito: un proyecto sin estimar
enseña «QUEDAN 2» y no se rompe nada. Si de las que faltan hay alguna sin medir,
los minutos son un suelo y el rótulo emergente lo dice.

**Lo que tachas hoy sigue contando.** Al completarla, una tarea se cae de `Hoy`
—deja de ser de hoy— pero no del bloque: si el denominador encogiera con cada
tacha, el filete iría de «0 de 3» a «0 de 2» a «0 de 1» y no avanzaría nunca.

**Pero solo mientras quede alguna.** Al tachar la última, el bloque entero
desaparece de `Hoy`, igual que desaparece una tarea suelta. En Pauta completar
saca de Hoy sin excepciones, y el bloque se salta esa regla únicamente por el
denominador; sin pendientes ese motivo ya no existe y lo que quedaría es una caja
de tachadas al final del día que además la cabecera ya no cuenta. **Que `Hoy` se
acorte es el premio** — el filete entero era uno peor, y para verlo cerrarse
haría falta un retardo que ninguna otra fila de la app tiene.

Esto mismo está en el teléfono, y lo decide el mismo código: `Hoy.bloques` y
`Pliegue` viven en el núcleo, así que las dos pantallas no pueden discrepar sobre
qué se agrupa ni sobre cuánto queda. Lo cuenta [`docs/ios.md`](docs/ios.md).

#### Arrastrar dentro y fuera

Soltar una tarea **dentro de un bloque la mete en ese proyecto**. La fila sobre
la que sueltas dice dos cosas y no una —la prioridad y, ahí dentro, el
proyecto—, y aplicar solo la primera hacía que el gesto mintiera: soltabas algo
entre dos tareas de Mudanza y aparecía debajo del bloque entero, porque el bloque
se dibuja de una pieza y aquello no era de Mudanza. Es el mismo caso que
«Próximamente» con el día, y se arregla igual.

Al revés no. Soltar **fuera** de un bloque no le quita el proyecto a nadie: una
fila suelta no es un sitio —puede ser la única tarea de otro proyecto hoy— y
desorganizar una tarea por arrastrarla dos filas sería destruir con el gesto que
sirve para ordenar el día. Para sacarla está *Mover a*, que lo dice en voz alta.
La consecuencia es que una tarea arrastrada fuera de su bloque vuelve a él, y se
lleva el bloque con ella si ha quedado por encima: el bloque va donde su primera
tarea. Es coherente, aunque no sea lo que se quería hacer con ese gesto.

#### Cerrarlo como un acordeón

Un proyecto con diez tareas se come la lista, así que **la cabecera se pliega**:
un clic y el bloque se cierra, dejando solo su línea. No se pierde nada, y aquí
se cobra lo de medir lo que queda en vez de lo hecho — cerrado, el rótulo sigue
diciendo «QUEDAN 2 · 45 MIN», que es lo que hacía falta saber. «3 de 5» plegado
no diría nada.

La cabecera **pliega, no navega**: cerrar se hace muchas veces al día e ir al
proyecto de vez en cuando, y para eso está la barra lateral ahí al lado y el menú
secundario en la propia cabecera. El galón de la izquierda está siempre a la
vista, y no solo al pasar el ratón: si lo único que avisara de que aquello se
pliega apareciera con el cursor encima, nadie sabría que se pliega.

**Se olvida al cambiar el día.** Lo que cerraste ayer hablaba de las tareas de
ayer; `Hoy` se rehace cada mañana, y dejarlo cerrado escondería trabajo nuevo
detrás de una decisión que ya no iba de esto. Dentro del mismo día sí aguanta,
aunque cierres la app: el pliegue es una decisión tuya, no un estado de la
ventana. Se guarda en `UserDefaults` y no en la carpeta, porque es cómo tienes
puesta la ventana en **este** Mac.

El filete cuenta **tareas** y no minutos, a propósito: es la ojeada, y tiene que
estar definida también cuando no has estimado nada. El coste es conocido —cuatro
cortas hechas y una larga pendiente lo pintan casi entero— y por eso la raya no
va sola y lo exacto se dice al lado.

### Lo que no se hizo a tiempo

Nada se pierde ni se queda atrás: una tarea planificada para un día que ya pasó
**sigue en `Hoy`**, día tras día, hasta que se haga o se replanifique. No se
mueve sola a hoy, porque su fecha original es información: dice cuánto llevas
arrastrándola.

Y lo dice: junto a la tarea aparece **el día para el que se planificó**, en gris
y con un icono de reloj. Sin eso, algo de hace tres días se leería igual que
algo de esta mañana. Va en gris y no en rojo a propósito — el rojo es de las
fechas límite, que son lo que de verdad aprieta; si todo gritara, nada diría
nada.

Lo atrasado **insiste**: vuelve a avisar a su hora, hoy mismo si aún no ha
llegado y mañana si ya pasó, y así cada día hasta que se haga. El aviso dice
desde cuándo —«Pendiente desde el 31 de agosto»— con la fecha escrita entera y
no «hace tres días», porque se escribe hoy y puede sonar mañana. Completarla es
lo único que lo calla, que es la única forma sensata de callarlo.

Solo insiste lo de hoy y lo atrasado. Una tarea de la semana que viene avisa el
día que le toca, no todos los días desde hoy.

Con las repetitivas hay una trampa. La siguiente se cuenta desde la fecha que
tenía, no desde hoy, para que una semanal completada con un día de retraso siga
cayendo en su día de la semana. Pero además **se avanza hasta pasar de hoy**: si
no, completar una diaria con tres días de retraso pariría una sucesora ya
vencida, y habría que completarla tantas veces como días de retraso llevara solo
para ponerse al día — la app pidiendo cuentas por unos días que ya pasaron. Y si
la serie terminó mientras la tarea estaba atrasada, no nace ninguna: ponerse al
día no revive una serie acabada.

### La hora

Toda fecha en Pauta es **un día**, normalizado a las 00:00; la hora es lo único
que mira el reloj. Se pone desde el propio menú de fecha —`Hora ▸`—, no desde un
control aparte: una hora sin día no significa nada, así que ponérsela a algo sin
fecha lo programa para hoy, y quitarle la fecha o aparcarlo se lleva la hora.

Va en un campo aparte y **no dentro de `when`**. `when` es un día y hay quince
sitios que lo normalizan para comparar, agrupar y ordenar; meterle una hora
dentro le daría dos significados al mismo campo, y la cuenta de la repetición
—que devuelve el arranque del día siguiente— la perdería en silencio. Un campo
aparte no se puede perder sin que se note.

En `Hoy` y en cada día de `Próximamente`, **lo que tiene hora va primero y por
hora**; debajo sigue mandando el orden manual. La hora gana a la prioridad
porque no es una preferencia sino una restricción de fuera: no puedes decidir
que las nueve van después de las seis. En un proyecto o en la bandeja no se
aplica, que ahí comparar horas de días distintos no diría nada.

Una repetitiva **hereda la hora** —y el margen, y las etiquetas, y los pasos,
estos sin marcar—: «todos los días a las nueve» exige que la segunda vuelta
también sean las nueve.

#### El margen

`Hora ▸ Avisar antes` adelanta el aviso 5, 10, 15, 30 o 60 minutos. Avisar a la
hora exacta llega tarde para casi todo: hay que cerrar lo que estabas haciendo,
moverte, prepararte. Con margen, el aviso dice «prepárate» en vez de «ya se te
pasó».

Adelanta **el aviso y no la tarea**: las nueve siguen siendo las nueve en la
lista, en el orden y en la cuenta atrás. Si se movieran las dos cosas, el margen
no serviría de nada.

El margen se ve en la fila —una campana junto a la hora— porque si no, el aviso
llegaría antes de la hora escrita y parecería que la hora está mal. Y solo se
manda **un aviso**, el adelantado: dos por tarea sería el doble de ruido para
decir lo mismo, y el tope de 60 se gastaría al doble de velocidad.

Un margen que se sale del día avisa la noche anterior —diez minutos antes de las
0:05 son las 23:55 de ayer—, que es cuando de verdad hay que enterarse.

#### El aviso

Una hora sin aviso sería una etiqueta, así que las tareas con hora avisan por el
sistema. El permiso se pide **la primera vez que hay algo que avisar**, no al
arrancar: quien no use horas no tiene por qué ver el diálogo. Si lo rechazas, la
hora sigue funcionando como orden y como rótulo, solo que muda.

Los avisos se **reconstruyen enteros** con cada cambio, en vez de irse añadiendo
y quitando uno a uno. Es más trabajo por cambio y muchísimo menos que razonar
sobre qué aviso quedó suelto de una tarea que se completó, cambió de día, se
borró o llegó de otro dispositivo. Se reprograma un segundo después del último
cambio, porque escribir un título cambia las tareas en cada tecla.

Hay un tope de **60**: el sistema descarta lo que pase de 64 por app, y sin tope
propio se perderían avisos sin decirlo. Se quedan los más cercanos, y el
[repaso](#el-repaso-del-día) ocupa uno de los sesenta cuando está encendido.

Es la API vigente, `UNUserNotificationCenter` — `NSUserNotification` está obsoleta
desde macOS 11 —, y con **tres disparadores distintos** según lo que haya que
hacer:

| Cuándo | Disparador |
|---|---|
| Algo de más adelante | Calendario con fecha completa, una sola vez |
| Algo de hoy o atrasado | Calendario de hora y minuto, **repitiendo** cada día |
| Algo [aplazado](#aplazar) | Por intervalo, una sola vez |

La repetición es de la **insistencia** y nunca de la serie repetitiva. Una serie
avanza creando la sucesora al completar la anterior, y esa trae su propio aviso;
un disparador repetitivo atado a la serie seguiría sonando cuando la serie ya
hubiera acabado.

Hay un delegado, y hace falta para dos cosas que sin él no ocurren:

- **El aviso se ve aunque Pauta esté delante.** El sistema lo silencia por
  defecto dando por hecho que ya estás mirando la app, y en una app de tareas ese
  es justo el momento en que más falta hace.
- **Pulsarlo abre la tarea**, en una lista donde se vea; y trae dos botones,
  **«Completar»** para despachar una rutina sin abrir nada y **«Aplazar»**, con
  los minutos que digan los [ajustes](#ajustes).

Y si el permiso está denegado, **la app lo dice**: una franja arriba de la lista,
con un atajo a los ajustes del sistema. Un aviso que no llega y se calla es peor
que no tener avisos, porque la tarea parece cubierta y no lo está.

#### Aplazar

Un aviso que llega en mal momento se descarta, y el descarte se lo lleva hasta
mañana. El botón **«Aplazar 10 min»** es la salida que evita eso, y está también
en el menú contextual de la fila, porque «ahora no puedo» se piensa igual mirando
la lista.

Diez minutos y no una hora: lo bastante para terminar lo que tenías entre manos y
lo bastante poco para que aplazar no sea otra forma de perderlo de vista.

Aplazar **no toca la hora de la tarea**. Si la moviera, cada aplazamiento
reescribiría el horario y una rutina de las nueve acabaría a las once sin que
nadie lo decidiera. Se guarda como un instante aparte, que gana al horario
mientras dure y lo devuelve en cuanto se cumple.

Se guarda en el archivo y no solo en el centro de notificaciones, por dos
razones: sobrevive a cerrar la app, y **la fila puede decirlo** —una luna con la
hora—. Un aplazamiento invisible sería una tarea callada hasta las y cuarto sin
que nada explicara por qué.

Cambiar el plan lo borra: mover el día, mover la hora, aparcar o completar. Ese
«ahora no» hablaba de otro momento.

Y a diferencia del aviso de una tarea atrasada, **no insiste**: suena una vez.
Por eso va por intervalo y no por calendario —un disparador de calendario se
cuenta al minuto, y aplazar diez minutos a las y media y treinta segundos daría
un momento ya pasado, que no suena nunca—.

Completar o aplazar desde el aviso **reprograma al momento**, sin esperar al
disparador que vigila los cambios: ese vive en la ventana principal, y un aviso
se atiende con la ventana cerrada. Sin eso, completar dejaría la insistencia
sonando y aplazar no volvería nunca.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --avisos
```

#### El repaso del día

Un aviso a hora fija —**8:30** por defecto— que dice qué quedó sin hacer:

```
Repaso del día
2 sin hacer de días pasados · 1 para hoy · 4 paradas desde hace semanas
```

Existe porque nada te lo cuenta si no abres la app, y antes, si no te acuerdas
de abrirla. Ese «acordarse» es justo lo que una app de tareas no puede pedir.

No es un aviso de tarea: no lleva una dentro, no se completa y no trae
«Aplazar» —aplazar el repaso solo sería aplazar la decisión, que es lo contrario
de para lo que existe—. Al pulsarlo se abre `Hoy`, que es donde se decide el día.

**Se programa uno solo y sin repetición**, aunque sea diario. El texto lleva las
cuentas dentro, y un disparador repetitivo seguiría cantando las de hoy dentro
de un mes. El siguiente se programa en cuanto algo cambia o cambia el día, que es
lo que mantiene el texto verdadero. Y las cuentas se hacen **para el día del
repaso** y no para hoy: el aviso se prepara la noche antes, y contar desde ese
momento llamaría «de hoy» a algo que por la mañana ya será de ayer.

Si no hay nada que decir, no suena. Un repaso que dice «nada» enseña a ignorar
los repasos, y de ahí a ignorar los demás avisos hay un paso.

La hora se elige en los [ajustes](#ajustes) —de 7:00 a 10:00— y se puede
**desactivar**: un repaso a una hora que no te sirve es un aviso que se aprende
a ignorar. Apagarlo se guarda como decisión y no como ausencia de dato, porque si
no, duraría hasta el siguiente arranque.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --avisos
# permiso de avisos: authorized
# avisos programados: 3
# repaso del día: a las 8:30 (programado)
# botones de «tarea»: Completar, Aplazar 10 min
# avisos entregados y sin descartar: 1
```

Y para comprobarlo de punta a punta hay que hacer sonar uno:

```bash
./build/Pauta.app/Contents/MacOS/Pauta --seed-alarm 12 10
# tarea: CF52FCCE-…
# hora: 13:46  ·  aviso 10 min antes
# suena: 13:36:00
# para borrarla: rm '…/Pauta/items/CF52FCCE-….json'
```

Crea una tarea con hora dentro de esos minutos, con el margen que se le diga.
Escribe en los datos de verdad a propósito —un aviso solo se puede probar
sonando— y dice el comando para borrarla, porque una tarea de prueba que se
queda es basura.

Dice lo **programado** y lo **entregado**, que no es lo mismo: lo primero es lo
que va a pasar y lo segundo lo que pasó. Sin lo segundo, «probar los avisos» era
mirar el código y confiar. Y los botones se leen del sistema, porque que estén
escritos en el código no significa que estén registrados.

### Cuidado con leer permisos desde el terminal

`--eventos` y `--reminders-status` **mienten cuando se lanzan a mano**, y lo
dicen. TCC no atribuye el permiso al binario que pregunta sino al *proceso
responsable*, que ejecutando el ejecutable desde una shell es el terminal: lo que
sale es el permiso del terminal, no el de Pauta. Pueden discrepar —y discrepan—
sin que ninguno esté roto. El estado de verdad se ve en `Ayuda ▸ Permisos`, que
corre dentro de la app. Los avisos no van por TCC y sí se leen bien desde
cualquier sitio.

### Listas de comprobación

Una tarea puede llevar pasos. Se ven al desplegarla, y en la fila cerrada aparece
la cuenta —`1/3`—, que se pone en verde solo cuando está entera: si toda cuenta
gritara, ninguna diría nada.

Son **pasos, no subtareas**: no tienen fecha, ni proyecto, ni prioridad propia.
Lo que se planifica sigue siendo la tarea; los pasos solo dicen por dónde va. Por
eso completar la tarea no los marca —si la reabres, la lista sigue donde estaba—
y vaciar el texto de un paso lo borra, porque un paso sin texto no dice nada.

El campo «Añadir paso» está siempre mientras la fila esté abierta: es lo que hace
descubrible que una tarea puede ser una lista.

### Etiquetas

Transversales a todo lo demás: una tarea puede llevar varias, y cada una es una
lista más en la barra lateral. Soltar una tarea sobre una etiqueta **se la añade
sin quitarle las otras** — a diferencia de las listas, las etiquetas no son
excluyentes. Una tarea creada dentro de una etiqueta nace con ella puesta.

`Casa` y `casa` son la misma, y los espacios de sobra se recortan. En cada fila
solo se muestran las etiquetas que la lista no da ya por sabidas: dentro de
`casa`, esa no se repite en cada línea.

Las etiquetas **salen de las tareas**, no de una lista aparte: existen mientras
algo pendiente las lleve, así que no quedan huérfanas que limpiar. El precio es
que renombrar una toca todas las tareas que la llevan; a cambio no hay una
entidad más que mantener viva. Renombrar y quitar están en su menú.

Cada proyecto puede llevar un emoji: se elige pulsando el círculo junto a su
título, de una paleta corta, y sustituye a su símbolo en la barra lateral.

### Cuánto dura cada cosa

Cada tarea puede llevar una **estimación** —de 5 minutos a 4 horas—, y la
cabecera de la lista suma lo estimado:

```
4 EVENTOS · 9 ABIERTAS · 3 H 30 MIN
```

Quince cosas en `Hoy` paralizan igual que ninguna, y la razón es que una lista no
dice cuánto ocupa: cabe todo hasta que se demuestra que no. Con la suma arriba, el
número se ve **antes** de que lo demuestre el día — y arriba y no en un pie,
porque la pregunta «¿cabe esto?» se hace antes de leer la lista, no después.

La app **no inventa una jornada de ocho horas** contra la que comparar. No sabe
cuántas horas tienes ni tendría cómo saberlo, y una barra roja apoyada en una
cifra inventada sería una regañina sin fundamento. «7 h 30 min» en un martes se
lee solo.

Solo suma lo abierto —lo hecho ya no ocupa el día que queda— y al pasar el cursor
dice cuántas van sin estimar, porque si no la suma daría a entender que el día
está medido cuando de diez tareas solo se midieron tres.

Es una creencia y no un dato: nadie mide después si acertaste. En la fila cerrada
se ve con un cronómetro —`⏱ 45 min`—; en la desplegada, el mismo icono es el
botón para ponerla. Un rótulo «SIN ESTIMAR» en cada fila pesaría más que el dato
que falta.

### Lo que se queda quieto

Una tarea **sin fecha** puede llevar cinco semanas ahí sin que nada lo diga.
Pasadas **tres semanas** desde que se apuntó, la fila lo dice: `⌛ 6 sem`. En
semanas hasta las nueve, y en meses cuando ya da vergüenza contarlas.

Se cuenta desde que se creó y no desde la última modificación: si contara desde
ahí, cambiarle una coma al título la dejaría como nueva, y una tarea que se
toquetea sin hacerse nunca no llegaría a estar rancia jamás.

Lo que tiene fecha no cuenta nunca — si se pasó, ya lo dice el retraso, y dos
marcas para lo mismo no dicen el doble. Lo aparcado en `Algún día` sí, porque
aparcarlo fue decir «no ahora», no «no me lo recuerdes nunca». Y el
[repaso](#el-repaso-del-día) las saca a la superficie, que es lo que evita que la
marca se convierta en parte del paisaje.

No se reordena la lista por esto. La prioridad manual es la que pusiste tú; una
marca informa, y reordenar sería decidir por ti.

### La bandeja se esconde cuando está vacía

La bandeja es una **estación de paso**: existe para vaciarse, así que vacía es su
estado normal y no algo que haya que anunciar cada mañana. Cuando aparece,
aparecer *es* el aviso de que hay algo por colocar — la misma regla que la
papelera.

Sigue estando si es la que estás mirando. Vaciarla y que la lista desaparezca de
debajo mientras la tienes delante se lee como un fallo, no como un premio.

`⌘1…⌘6` **no se mueven**. Aunque la bandeja no esté en la barra lateral, `⌘1`
sigue llevando a la bandeja: un atajo que cambia de destino según lo que haya
dentro no es un atajo.

Y **no se esconde en el teléfono**, donde la bandeja es una de las cuatro
pestañas. Una fila que aparece en una barra lateral no molesta a nadie; una barra
de pestañas que se recoloca bajo el pulgar cambia de sitio los tres botones que
sí usas.

Lo que llega ahí, por si hacía falta contarlo: lo que dictas por voz en el
iPhone y en el reloj, lo que apuntas con `⌃Espacio` sin marcar «hoy», una tarea
nueva creada desde una lista que no la admite, las tareas que suelta un proyecto
al borrarse, y lo que devuelves de la papelera cuyo proyecto ya no existe.

## La papelera

**Borrar nunca borró.** Desde siempre pone una lápida y la carpeta la guarda
treinta días; lo que faltaba no era guardar, era **una puerta**. Sin ella, borrar
era la única acción sin vuelta atrás de toda la app — alcanzable en el teléfono
con un deslizamiento, el mismo gesto con el que se archiva un correo, sobre una
lista que también borra proyectos y áreas enteras. Y como la carpeta va por
iCloud, un deslizamiento mal dado llegaba al Mac y al reloj antes de que
levantaras el dedo.

La papelera **solo aparece cuando tiene algo**. Una lista vacía permanente en la
barra lateral es un recordatorio diario de una cosa que no ha pasado; y cuando
aparece, aparecer *es* el aviso de que algo se borró.

Ahí dentro nada se tacha ni se edita: una tarea borrada no es una tarea
pendiente. Solo se devuelve. Y cada fila dice **cuánto le queda**, no cuándo se
borró — lo que hace falta saber mirando la papelera es de cuánto tiempo
dispones. Sale del mismo plazo que hace la limpieza, así que no puede decir una
cosa y que pase otra.

### `⌘Z`

Deshacer devuelve **lo último que borraste**, sea tarea, proyecto o área: el
error que se deshace es casi siempre el que acabas de cometer, y para ese caso
abrir una lista y buscar la fila es más camino del que hace falta. Para lo de
ayer está la papelera.

El orden sale de una pila y no de la fecha de borrado. Las fechas se redondean
al milisegundo, así que dos borrados seguidos empatan y el desempate lo decidiría
el orden en que se miraran las listas; una pila sabe cuál fue el último porque
estaba delante cuando pasó. No se guarda en disco: deshacer es de esta sesión y
de este aparato, y lo que sobrevive es la papelera.

### Recuperar un proyecto recupera sus tareas

Borrar un proyecto no borra sus tareas: las suelta en la bandeja. Devolverlo
tiene que devolvérselas, porque recuperar un proyecto vacío y volver a archivar
quince tareas a mano no es recuperar nada — así que la lápida apunta cuáles
soltó.

Pero **solo lo que sigue suelto**. Si mientras tanto le diste otro sitio a una
tarea, ese sitio gana: fue una decisión tuya y posterior, y deshacer un borrado
no puede deshacer también lo que hiciste después. Lo mismo un escalón más arriba:
un área recupera sus proyectos. Y la fila lo dice antes de que pulses —«vuelve
con 2 tareas»—, que un proyecto vacío y uno con quince dentro se leen igual en
una lista.

Si la tarea que devuelves tenía un proyecto que ya no existe, vuelve a la
bandeja: una tarea con un `projectID` que no está no sale en ninguna lista, y un
«recuperado» que la deja invisible es peor que no recuperarla.

### Vaciar no borra el archivo: lo caduca

Vaciar la papelera se pide a mano y con una confirmación, porque a partir de ahí
no hay vuelta atrás. Pero **no borra los archivos**, y eso costó un rato
entenderlo.

Borrarlos era lo obvio y no funcionaba. El puente con el teléfono **no borra
nunca**: le copia a cada lado lo que le falta, que es lo que permite que un cruce
con la carpeta equivocada se deshaga cruzando con la buena. Así que vaciar en el
Mac quitaba el archivo y el siguiente cruce lo traía de vuelta desde el teléfono
—que seguía teniendo su copia—. La papelera se rellenaba sola en segundos y desde
fuera parecía que el botón no hacía nada.

Lo que sí viaja es un **cambio** del archivo, porque entre dos versiones gana la
más reciente. Así que vaciar le pone a la lápida una fecha de borrado ya vencida.
El otro aparato la recibe caducada, tampoco la enseña, y la limpieza de los
treinta días —que ya existía— se lleva los archivos en los dos lados. Una lápida
caducada no sale en la papelera ni se puede recuperar: no espera a que la
recuperes, espera a que la barran.

Detalle que se descubrió probándolo: la caducidad se escribe con una fecha
**estrictamente posterior** a la que tenía, no con «ahora». Las fechas se
redondean al milisegundo, así que borrar algo y vaciar la papelera acto seguido
daban el mismo sello y el puente no veía ganar a la caducidad.

Y otro, que se descubrió con los datos de verdad: la limpieza miraba solo la
fecha de borrado, y como vaciar la pone un mes atrás, **el siguiente arranque
barría el archivo en el acto**. Si el Mac se reabría antes de que el teléfono
cruzara —bastaba abrir las dos apps a la vez—, al Mac le faltaba el archivo y el
teléfono le devolvía su copia sin caducar: la papelera, llena otra vez. Ahora la
limpieza exige que también la última modificación tenga más de treinta días. La
última modificación es la del vaciado, así que una lápida caducada se queda un
mes en la carpeta, invisible, el mismo plazo que ya se daba a cualquier otra
para que el otro aparato se enterase.

## Vaciar la bandeja

La bandeja existe para poder **apuntar sin decidir**. El precio es decidir
después, y ese después no llega: se abre una lista de sesenta cosas, hay que
elegir por dónde empezar —que es otra decisión, la más cara—, se cierra la lista
y no se vuelve. Así es como una bandeja se convierte en el sitio donde las cosas
van a morir.

`VACIAR`, en la cabecera de la bandeja, lo da la vuelta: **una tarea delante,
cinco decisiones, la siguiente.**

```
VACIAR LA BANDEJA                    1 DE 12   Cerrar

Comprar entradas del concierto

  ☀  Hoy                                    H
  🌅 Mañana                                  M
  📅 Próxima semana                          S
  📦 Algún día                               A
  📁 A un proyecto                           ▾
  →  Saltar        ↩       🗑 Eliminar      ⌫
```

No se puede reordenar ni priorizar, y es a propósito: esto no sirve para
organizar la bandeja, sirve para dejarla vacía. Todas las decisiones la sacan de
ahí —una que la dejara donde estaba no sería una decisión—.

**Saltar** existe porque hay cosas que de verdad no se pueden decidir ahora, y
forzar una decisión es como se acaba con una lista llena de fechas falsas. Al
final se dice cuántas quedaron: «Bandeja casi vacía · dejaste 3 para luego».

En el Mac **va con el teclado**, que es lo que un Mac puede hacer y un teléfono
no: la inicial de cada decisión, `⌫` para eliminar y `↩` para saltar. Veinte
tareas en veinte pulsaciones, sin soltar la mano. Los atajos se enseñan en el
propio botón, porque uno que hay que aprenderse en otro sitio no se usa. La fila
del proyecto no anuncia tecla: un menú no se abre con una pulsación suelta, y un
atajo que se promete y no funciona es peor que no tenerlo.

La cola **se congela al abrir**. Despachar una tarea la saca de la bandeja, así
que una lista viva se reordenaría bajo la mano y perdería la cuenta de cuántas
quedan; y así puede entrar algo nuevo por Siri sin empujar nada.

## La fecha se saca de lo que escribes

Escribes **«Llamar a la gestoría mañana a las 10»** y sale una tarea que se llama
*Llamar a la gestoría*, para mañana, a las diez. Escribirlo y luego abrir un
selector para repetirlo es hacer dos veces el mismo trabajo.

Quien entiende el español es `NSDataDetector`, que trae el sistema: sabe de
«pasado mañana», «el viernes» y «el 3 de octubre» sin que en el código haya una
sola lista de meses. Va sin red, sin cuenta y sin coste. Lo que pone Pauta es lo
que él no hace:

**No se inventa nada.** «Comprar pan» no tiene fecha, y «Comprar 3 cajas de
leche» tampoco — un número suelto no es un día. Una tarea con fecha que tú no
pediste es peor que una tarea sin fecha, porque además trae aviso.

**Día sin hora deja la hora en blanco.** El detector rellena las doce del
mediodía cuando no le dices ninguna; tragárselo le pondría a la tarea una hora
inventada, y a las doce sonaría un aviso que nadie pidió.

**Se limpia lo que queda colgando.** Al sacar la fecha del medio quedan
preposiciones sueltas —«Cita con el dentista **el**»— que no son título de nada.

**Y se juntan los trozos.** Este es el caso que lo motivó:

```
«28 de Septiembre de Sección de Inicio de Uned a las 18:00»
```

Con el título metido **entre** la fecha y la hora, el detector saca dos trozos
sueltos: «28 de septiembre», que se inventa las doce, y «18:00», que se inventa
hoy. Ninguno acierta solo. Se combinan —el día del que trae día, la hora del que
trae hora— y sale *Sección de Inicio de Uned*, el 28 a las 18:00.

Si al quitar la fecha no queda título, no se toca nada: escribir «mañana a las
10» crea una tarea que se llama así, no una tarea en blanco con fecha.

Esto vive en el núcleo y se engancha en `addItems(from:)`, que es por donde entran
**todas**: la fila de la lista, el panel del atajo, la barra de menús, la captura
del teléfono, el atajo de Siri y lo que le dictas al reloj. Seis interfaces que
entienden lo mismo porque llaman a lo mismo, no porque se hayan puesto de acuerdo.

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

## Alta rápida

**⌃Espacio** abre una línea para apuntar algo, esté delante lo que esté delante.
Va a la **bandeja**; con ⇧⏎, a `Hoy`. Varias líneas pegadas de golpe son varias
tareas, igual que en la lista.

Existe porque ⌘N solo sirve con Pauta delante, y la cosa que hay que apuntar
aparece **mientras estás en otra cosa**: leyendo un correo, al teléfono, a mitad
de otra tarea. Si apuntarla exige cambiar de app, buscar la ventana y volver, no
se apunta — y lo que no se apunta no lo arregla ninguna lista.

Y va a la bandeja a propósito. Capturar y decidir son dos gestos distintos;
juntarlos es lo que hace que apuntar cueste. La bandeja permite escribirlo mal,
deprisa y sin pensar dónde va.

El atajo se registra con **Carbon** (`RegisterEventHotKey`) y no con
`NSEvent.addGlobalMonitorForEvents`: el monitor global exige permiso de
monitorización de entrada —el mismo que se le pide a un registrador de teclas— y
pedir eso para apuntar tareas es desproporcionado. `RegisterEventHotKey` no pide
nada porque no ve el resto de las teclas.

### Cambiar el atajo

⌃Espacio es el de fábrica, y **se cambia en los ajustes**: se pulsa el campo y se
teclea la combinación que sea. El que esté puesto se lee ahí mismo y en la
ayuda, para no tener que adivinarlo.

No hay botón de menú para el alta rápida. Un atajo global no se declara en el
menú —lo registra Carbon, para que funcione con otra app delante— y un botón
que abre un panel flotante estando ya dentro de la app no hace nada que ⌘N no
haga mejor. `Archivo` se queda con lo que crea cosas y con la importación, que
es lo que un menú de archivo hace.

Se exige **⌃, ⌥ o ⌘**. Sin uno de esos, el atajo se comería una tecla en todas
las apps: dejar «A» como alta rápida es dejar de poder escribir una a en
cualquier sitio. Mayúsculas no cuenta, que ⇧A sigue siendo escribir.

El nombre de la tecla se le pregunta **al teclado de verdad**, con
`UCKeyTranslate`. Un código de tecla es físico: con una tabla fija saldría el
QWERTY americano, y en un teclado español la tecla de la ñ diría «;».

Si ⌃Espacio estuviera cogido —lo usa el conmutador de fuentes de entrada de
macOS cuando hay más de un teclado configurado— la app se cae sola a ⌥Espacio y
luego a ⌃⌥Espacio, y guarda el que quedó: quedarse sin atajo es quedarse sin la
mitad de la app.

Y una cosa que no se puede detectar y por eso se dice: cuando otra app o el
sistema se queda una combinación, **`RegisterEventHotKey` no falla** —devuelve
que sí— pero la tecla nunca llega. Si al pulsar no pasa nada, es eso; los ajustes
lo advierten y hay que elegir otra.

Los permisos del calendario también salieron de `Archivo`: estaban ahí por no
tener otro sitio, y ahora lo tienen en la [ayuda](#acerca-de-y-ayuda) junto a los
otros dos, donde además se piden.

Al abrir, **la app se activa**: el sistema entrega las teclas a la que está
delante, así que un panel de una app de fondo se ve, se puede pulsar y no recibe
una sola letra. El precio es que la ventana principal sube detrás del panel; se
paga porque la alternativa es un panel donde no se puede escribir, y **al cerrar
el foco vuelve a donde estaba**, que es lo que hace que esto interrumpa un
segundo y no un minuto.

## Barra de menús

El monograma junto al reloj abre un panel con las tareas de Hoy: completarlas
con su casilla, añadir una nueva (que cae en Hoy) y reabrir la ventana
principal, todo sin cambiar de app. Y a diferencia del [widget](#el-widget), aquí
sí se puede **tocar**: el panel es la app, no una copia de lectura.

### La cuenta atrás

Cuando lo siguiente con hora está a **menos de una hora**, el monograma se
acompaña de cuánto falta y de qué es: `En 20 min · Recoger a los niños`. Un aviso
puntual llega, se oye y entre medias no hay forma de saber cuánto queda sin abrir
algo y mirarlo; esto pone el dato a la vista sin preguntar.

Solo dentro de esa ventana. Un rótulo puesto todo el día —«en 9 h»— se deja de
leer, y entonces tampoco dice nada cuando falta un cuarto de hora, que es el
único momento en que hacía falta.

Cuenta **solo tareas**. Los eventos del calendario ya los avisa el sistema, y
contarlos aquí también sería avisar dos veces de lo mismo. Y cuenta la hora de la
tarea, no la del aviso: el margen adelanta la campana, no el momento.

## El widget

En el centro de notificaciones y en el escritorio, en tres tamaños. Enseña lo
mismo que el del teléfono: **«3 para hoy»**, las atrasadas aparte y en rojo, las
primeras tareas con su hora y lo que queda sin decidir en la bandeja. Lo que no
cabe lo dice —«+3 más»—, y con el día vacío se convierte en un botón de apuntar.
Un clic abre la app donde toca: Hoy, la bandeja, o el panel del atajo.

**Aquí solo lee**, y no por gusto: en el teléfono el círculo de cada fila tacha
la tarea —el widget escribe en la carpeta del grupo, que es donde viven los datos
allí—, pero en el Mac la extensión va en sandbox y tus tareas están en iCloud
Drive, así que **no puede escribirlas**. Para tachar sin abrir la ventana está el
[panel de la barra de menús](#barra-de-menús), que sí es la app y hace
exactamente eso.

Lo que se podría hacer el día que moleste: que el widget deje una **orden
pendiente** en la carpeta del grupo y la app la aplique al siguiente latido —el
reloj de la barra ya late cada medio minuto—. Funcionaría con la app abierta, que
es el caso normal con el arranque al iniciar sesión; con la app cerrada la orden
esperaría, y el widget tendría que decir que está pedida y no hecha. Es un estado
más que hay que dibujar con cuidado, y por eso no está.

### Por qué el Mac necesita una instantánea y el teléfono no

Un widget es **otro proceso y otra caja**. En el teléfono eso se resuelve
moviendo los datos a la carpeta de un grupo de aplicaciones, que la app y la
extensión ven las dos. Aquí no se puede: tus datos están en **iCloud Drive**, y
una extensión de widget en macOS va en sandbox —no se carga de otra manera—, así
que por ruta no entra. Y entrar por la puerta buena exigiría el contenedor de
ubicuidad, que es justo el atajo del que vive esta app: para ella iCloud Drive es
una carpeta normal.

Así que la app le deja escrito lo que hay que enseñar: un `vistazo.json` en la
carpeta del grupo, con los números, las nueve primeras tareas y **el día del que
habla**. Se publica cuando cambian las tareas y al cruzar la medianoche —el reloj
de la barra ya late cada medio minuto, así que no hace falta otro temporizador—.

El día que lleva dentro es lo que salva al widget de mentir: si la app está
cerrada, lo escrito envejece, y entonces el widget dice **«Abre Pauta para ver el
día»** en vez de enseñar la lista de ayer como si fuera la de hoy.

El mismo arreglo, y por el mismo motivo, es el que lleva Pauta a la **esfera del
reloj**: allí la app tampoco comparte memoria con su complicación, así que
escribe el vistazo en la carpeta del grupo y la esfera lo lee. La regla de
descartar lo que no es de hoy vive en el núcleo y la usan las dos. Está contado
en [El reloj](docs/ios.md#la-complicación).

Para ver qué tiene escrito, sin adivinar:

```bash
./build/Pauta.app/Contents/MacOS/Pauta --vistazo
# grupo: 26W4G92PSS.dev.jadrdev.pauta
# día: 9 sept 2026  (es de hoy)
# titular: 2 para hoy  ·  1 atrasada
#   · Revisión diaria  20:00
#   · Video  (atrasada 1 d)  [Aguere Games]
```

Existe porque **desde fuera no se puede mirar**: la carpeta de un grupo está
protegida por el sistema y un terminal no entra ahí. La app sí, porque el grupo
es suyo.

## Ajustes

`⌘,`. Unas pocas cosas, y son pocas a propósito: un ajuste por cada decisión de
diseño convierte la app en un panel de control y hace que todos los valores por
defecto parezcan arbitrarios. Aquí solo está lo que **cambia de persona a
persona**.

- **Abrir Pauta al iniciar sesión.** No es comodidad: con la app cerrada no hay
  atajo global, el repaso no se reprograma y la cuenta atrás no está en ninguna
  parte. Una app que hay que acordarse de abrir para que te acuerde de las cosas
  no sirve. Va por `SMAppService`, y si el sistema lo rechaza —suele ser porque
  la app no está en `Aplicaciones`— el interruptor vuelve solo y lo dice, en vez
  de quedarse encendido mintiendo.
- **La hora del repaso**, o apagarlo. Antes vivía en el menú `Archivo`, entre
  acciones; una preferencia no es una acción.
- **Margen de aviso por defecto**, para no ponerlo tarea por tarea. Es un valor
  **de partida y no una regla viva**: se aplica al poner una hora nueva y respeta
  el margen que la tarea ya tuviera. Si mandara siempre, cambiarlo reescribiría
  en silencio el de todo lo ya planificado.
- **Cuánto aplaza** el botón. Los diez minutos eran una decisión escondida en el
  código. Al cambiarlo se vuelve a registrar la categoría del aviso, porque el
  título del botón se congela al registrarla: sin eso seguiría diciendo «Aplazar
  10 min» y aplazando quince.
- **La cuenta atrás en la barra de menús**, o solo el icono. La barra de menús es
  de todos y hay pantallas donde no sobra sitio.
- **El atajo del alta rápida**. Se graba pulsándolo: el campo escucha la
  siguiente combinación y la registra.
- **Avisar de versiones nuevas**, con su botón de `Buscar ahora`. Es la única
  vez que la app habla con internet por su cuenta, así que se puede apagar y se
  dice ahí mismo qué hace. Más abajo, [Versiones nuevas](#versiones-nuevas).

Lo que no está y no va a estar: el umbral de lo rancio, la ventana de la cuenta
atrás, la duración de una jornada contra la que medir el día. Son juicios de la
app, y volverlos ajustables sería pedirte que los tomes tú sin darte con qué.

Se guardan en `UserDefaults` y no en la carpeta de datos: son preferencias de
**este Mac** —la hora a la que te levantas aquí, el sitio que te sobra en esta
pantalla— y no cosas que deban viajar con las tareas. En [maqueta](docs/compilar.md#modo-maqueta)
son de mentira y en su propio dominio: mirar el diseño no debe cambiarte los
ajustes de verdad.

## La bienvenida

En un teléfono o un Mac recién instalados, debajo del vacío de `Hoy` aparece una
tarjeta con **los permisos que aún no se han contestado**, cada uno con su motivo
en una línea y su botón:

```
PARA QUE SIRVA DE ALGO
🔔 Avisos          Sin ellos, una hora es solo una etiqueta.        [Activar]
📅 Calendario      Para que Hoy sea el día entero y no solo tus     [Activar]
                   tareas.
```

**No hay asistente de páginas**, y no por pereza: pedir los permisos antes de
que se haya visto una sola tarea es pedirlos antes de que exista el motivo, y
aquí un «no» es **para siempre** porque ni macOS ni iOS vuelven a preguntar. La
tarjeta va donde ya hay hueco, se puede ignorar, y la app es usable desde el
primer segundo — que es la promesa de no tener cuentas ni configuración.

El motivo de cada permiso dice **qué se pierde sin él**, no qué se concede.
«Pauta quiere acceder a tu calendario» no es una razón, es un trámite.

Solo lista lo que está **sin contestar**. Un permiso denegado no vuelve aquí a
insistir: eso ya lo dicen la franja de su sitio y la pantalla de permisos. Una
tarjeta que no se va nunca deja de ser una bienvenida y pasa a ser una regañina.
Cuando están todos decididos, desaparece.

Y nada pide permiso por su cuenta al arrancar. **Registrarse a los cambios de un
`EKEventStore` también lo pide** —conectar con el demonio dispara el diálogo—,
así que el vigilante no se monta hasta que hay permiso. Sin eso, la tarjeta
llegaba tarde a su propia fiesta.

## El globo del icono

Cuando tienes tareas **atrasadas**, el icono lleva el número. Cuando no, no lleva
nada — y nunca lleva un cero.

Esa restricción es lo que lo hace funcionar. Un globo con «lo de hoy» estaría
encendido todas las mañanas, dejaría de leerse, y el día que hubiera algo raro no
te enterarías: es el mismo razonamiento por el que la cuenta atrás de la barra de
menús solo sale cuando falta menos de una hora. Lo atrasado es distinto porque
**se apaga haciendo el trabajo**. Un globo que puedes quitar trabajando es la
definición de un globo bueno.

La cuenta es la misma que el apunte del widget y que la marca de cada fila
—planificada para un día que ya pasó—, y sale del mismo `Vistazo`. Cuatro sitios
diciendo lo mismo con números distintos es cuatro veces peor que no decirlo.

### El globo no salía, y no era culpa del globo

La primera versión no pintaba nada. La tentación era tocar AppKit; medirlo dijo
otra cosa. Desde fuera no se le puede preguntar al Dock qué tiene puesto, así que
se midió desde dentro, y contestó:

```
globo=2  app=ok  politica=0  releido=2  hilo=principal
```

AppKit lo aceptaba y lo devolvía al releerlo. **No fallaba pintar: nadie llamaba
a la función.** `publicarVistazo` vivía solo en un bloque que espera un segundo y
se reinicia con cada cambio del almacén, y al arrancar hay una ráfaga —cargar la
carpeta, lo que baje de iCloud, el vigilante— entre cuyas cancelaciones tardaba
minutos en ejecutarse, o no se ejecutaba. Doce segundos después de abrir la app:
cero publicaciones.

Así que el fallo era más gordo que el globo. Ese mismo bloque es quien refresca el
widget y manda el vistazo al reloj: **al arrancar, el Mac no publicaba nada**. El
teléfono ya tenía este arreglo —está comentado en su código desde que se descubrió
allí— y el Mac se había quedado sin él. Ahora publica también al arrancar.

**En el Mac lo pinta el propio proceso** (`NSApp.dockTile.badgeLabel`), así que
solo existe mientras la app corre: si la cierras del todo no hay globo, y vivir en
la barra de menús es lo que hace que eso no importe casi nunca.

Y **se dibuja a mano**, que no era el plan. Lo obvio es `badgeLabel`, y no vale
para quien ya tenía la app instalada: AppKit acepta el valor y lo devuelve al
releerlo —`releido=2`—, pero quien decide si se dibuja es el sistema, y el globo
es un permiso que se concede **al aceptar los avisos, de una vez**. Pauta pedía
`.alert` y `.sound`, así que nunca lo tuvo.

Añadir `.badge` a la petición no lo arregla, y eso también se midió:

```
antes=false  request=true  despues=false
```

El sistema contesta que sí a la petición —ya estaba autorizada— y deja el globo
denegado. Ajustes del Sistema ni siquiera enseña el interruptor, porque la app no
lo pidió el día que importaba.

**Y aquí los dos sistemas no se comportan igual**, que es lo que costó ver. En
macOS borrar y reinstalar no sirve: esa decisión va por identificador de paquete y
sobrevive —comprobado borrando el paquete ocho veces seguidas, `authorized` en
todas—. **En iOS sí**: desinstalar la app se lleva su permiso de notificaciones,
así que al volver a instalarla pregunta de cero y esta vez con el globo dentro.
Comprobado también: en el teléfono el número apareció después de borrarla y
reinstalarla, y no había ninguna otra forma de conseguirlo.

El precio en iOS es real y hay que decirlo: al borrar la app se va su copia local
de las tareas y el marcador de la carpeta del Mac. Lo primero se recupera del
Mac; lo segundo hay que volver a elegirlo.

Así que Pauta pinta su propia baldosa: el icono y encima una cápsula roja con el
número. `NSDockTile.contentView` no pide permiso a nadie. El precio es dibujar
también el icono, porque poner una vista propia sustituye la baldosa entera; y las
medidas van en proporción al lado, no en puntos, porque el Dock la dibuja al
tamaño que cada uno tenga puesto.

**En el teléfono lo pone el sistema** y sobrevive a cerrar la app, que es justo
cuando sirve. El precio es que `.badge` es un permiso aparte, y Pauta pedía solo
`.alert` y `.sound` hasta la 0.3.8. A quien ya había concedido los avisos **el
sistema no le vuelve a preguntar**: se comprueba con

```bash
/Applications/Pauta.app/Contents/MacOS/Pauta --avisos
```

que dice `globo en el icono: no permitido` en ese caso. Por eso la app **lee el
estado en vez de suponerlo**, y cuando está apagado la pantalla de ajustes del
teléfono enseña una fila que lleva a encenderlo. Instalando de cero no hace falta:
el permiso se pide con los avisos.

## Versiones nuevas

La app **avisa, no instala**.

Una vez al día, al arrancar, le pregunta a la API de GitHub cuál es la última
versión publicada del repositorio. Si es más nueva que la que tienes, aparece
una línea discreta en el panel de la barra de menús —*Hay una versión nueva ·
0.4.0*— y el estado cambia en los ajustes, con un enlace a la página de la
versión. Nada más: ni ventana modal, ni insistencia, ni número rojo.

**Por qué no se instala sola.** Lo normal aquí sería Sparkle. Instalar sola una
app descargada obliga a verificar la firma de lo que se baja antes de sustituir
lo que ya está —si no, el mecanismo de actualización es la forma más cómoda que
existe de meterte otra cosa—, y esta app se firma con un certificado de
desarrollo local y **sin notarizar**: no hay Developer ID con el que la
comprobación signifique algo. El muro es la cuenta de Apple, no el código. Así
que se avisa y el resto es arrastrar el `.app` al `.dmg`, como hasta ahora. El
día que haya cuenta de pago, esto se puede convertir en una actualización de
verdad sin tocar nada de lo demás.

**Qué se manda.** Una petición `GET` a
`api.github.com/repos/jadrdev/pauta/releases/latest`, sin cuenta, sin clave y
sin nada tuyo dentro. No se manda qué tareas tienes, ni cuántas, ni desde dónde
miras. La sesión es efímera y sin caché en disco, con diez segundos de paciencia:
es una pregunta de fondo y no algo por lo que valga la pena esperar.

**Cuándo.** Una vez cada veinticuatro horas como mucho, y solo al arrancar.
Preguntar en cada apertura sería gastar la red de otro por costumbre, y esto se
publica cada varios días. Apagado en los ajustes es apagado del todo: ni la
primera vez. El botón `Buscar ahora` mira aunque no toque.

**Y si falla.** Si no hay red, si GitHub está caído o si contesta algo que no se
entiende, no pasa nada: no hay error, no hay diálogo, se prueba mañana. Lo que
sí se distingue es *no se pudo comprobar* de *tienes la última*; decir lo
segundo cuando pasó lo primero es mentir en voz baja.

La versión con la que se compara sale del `Info.plist`, y se comparan **números
y no textos**: como cadena, la `0.10.0` va antes que la `0.9.0`, y la app
dejaría de avisar sin que nadie supiera por qué. Los borradores y las previas de
GitHub no cuentan como versión.

## Acerca de y ayuda

Dos fichas de lectura, del tamaño de su contenido y sin poder estirarse: una
ficha con media ventana en blanco se lee peor.

**`Pauta ▸ Acerca de Pauta`** sustituye al panel del sistema, que enseña icono,
nombre y versión y para ahí. Además dice **dónde están tus datos** —la ruta, si
va por iCloud, y un enlace para abrir la carpeta—, que es la pregunta que de
verdad se hace quien abre esto en una app que guarda archivos sueltos en una
carpeta y no en una base de datos escondida. La versión sale del `Info.plist` y
no de una constante en el código: la pone el empaquetado, y escribirla dos veces
es garantizar que un día discrepen.

**`Ayuda ▸ Ayuda de Pauta`** (`⌘?`) lleva las dos cosas que no se pueden leer en
ningún otro sitio:

- **Los atajos**, empezando por el global — que si no se conoce, no existe. Y se
  enseña el que quedó **registrado**, no el que se pidió: si ⌃Espacio estaba
  cogido, la app cayó a otro, y decir el primero sería mentir.
- **Los permisos** —avisos y calendario— con su estado leído en vivo. Sin
  preguntar, se piden desde ahí; denegados, se enlaza a los ajustes del sistema,
  que es el único sitio donde esa decisión se cambia: el diálogo no vuelve a
  salir. Dos funciones de la app las da el sistema, y cuando dice no, esa parte
  se queda muda; una app que no lo explica parece rota.

No es un **libro de ayuda de Apple**. Un help book exige empaquetar un bundle de
HTML con su índice hecho con `hiutil` y confiar en el visor del sistema, para un
contenido que cabe en una pantalla. La guía larga es este README, y desde la
ventana se abre.

Y no se restauran al arrancar. macOS reabre lo que estaba abierto al salir, que
para la ventana principal está bien —es donde estabas— pero arrancar con el
«Acerca de» delante se lee como un fallo. `isRestorable` de la ventana no sirve:
la restauración la lleva SwiftUI por el id de la escena, así que se cierran por
ahí al arrancar.

### El idioma de los menús

`Archivo`, `Edición`, `Ventana`, `Ayuda`… los pone AppKit, y los deja **en
inglés** salvo que el bundle declare algún idioma. En una app escrita entera en
español eso se lee como un descuido, así que el paquete lleva un `es.lproj` y
declara `es` en `CFBundleDevelopmentRegion`. El archivo de cadenas apenas tiene
contenido: lo que hace falta es la declaración.

Lo único que queda en manos del sistema es el `Enviar opinión sobre Pauta a
Apple` que macOS inserta en el menú de ayuda. Apple no tiene nada que ver con
esta app; al lado está `Informar de un problema`, que va a las incidencias del
repositorio.
## La app de iOS

Existe, se instala en un iPhone y comparte con el Mac **todo el núcleo y ninguna
vista**. Las listas son las mismas —calculadas por el mismo código—; la forma de
andar por ellas, no: pestañas abajo, título grande y un botón flotante para
apuntar.

Y trae **un widget**, que es la única parte de la app que se ve sin abrirla:
«3 para hoy», las atrasadas aparte y en rojo, las primeras tareas con su hora y
lo que queda en la bandeja. Con el día vacío se convierte en un botón de apuntar,
porque es lo único útil que se puede hacer desde ahí. Y **el círculo tacha**: se
completa desde la pantalla de inicio sin abrir la app, que era la mitad que
faltaba del gesto.

**[El capítulo del teléfono →](docs/ios.md)** — la estructura, el widget, cómo se
compila para el simulador y para un iPhone de verdad, sus ajustes y lo que
todavía no puede hacer.

## Instalar

Con **Homebrew**, que además deja las actualizaciones a una orden:

```bash
brew tap jadrdev/pauta
brew trust jadrdev/pauta
brew install --cask pauta
xattr -dr com.apple.quarantine /Applications/Pauta.app
```

El `brew trust` lo pide Homebrew 7 para cualquier tap que no sea el oficial, y
tiene sentido: un cask es código que se ejecuta en tu Mac. La última línea es el
mismo muro de siempre —está explicado justo debajo— y hay que repetirla en cada
actualización, porque cada versión se baja otra vez. Hubo una bandera
`--no-quarantine` que se lo saltaba; **Homebrew 7 la quitó**.

Y a partir de ahí, cuando la app [avise de que hay versión
nueva](#versiones-nuevas):

```bash
brew upgrade --cask pauta
xattr -dr com.apple.quarantine /Applications/Pauta.app
```

**Eso cierra la mitad que a la app le falta.** Pauta avisa pero no instala,
porque instalar sola algo descargado obliga a verificar la firma de lo que se
baja y con esta cuenta no hay con qué. Homebrew sí verifica —el cask lleva el
`sha256` del disco y lo comprueba antes de tocar nada—, así que `brew upgrade`
es el instalador que la app no puede tener. La receta vive en
[jadrdev/homebrew-pauta](https://github.com/jadrdev/homebrew-pauta).

**O a mano:** el disco `.dmg` va en la [página de versiones](https://github.com/jadrdev/pauta/releases).
Se abre, se arrastra Pauta a `Aplicaciones` y ya está.

La primera vez macOS **no la va a dejar abrirse**, y conviene saber por qué en
vez de pelearse con el mensaje: Gatekeeper solo confía en lo que se descarga si
está firmado con un certificado *Developer ID* y notarizado por Apple, y el disco
va firmado con un certificado de desarrollo. Sin esas dos cosas dice que la app
«está dañada», que no es verdad y no explica nada. Se le quita la cuarentena a
mano:

```bash
xattr -dr com.apple.quarantine /Applications/Pauta.app
```

No lo hagas con una app que no sepas de dónde viene. Aquí el código está entero
a la vista y puedes compilarlo tú, que es la otra salida y la mejor.

Este párrafo no se quita con trabajo: el certificado *Developer ID* que hace
falta para notarizar lo da el **programa de pago** de Apple, y esta cuenta es un
equipo personal. Mientras siga así, la cuarentena se quita a mano o se compila
el código.

Y si prefieres compilarla: **[compilar, firmar y empaquetar →](docs/compilar.md)**.
## Compilar y ejecutar

```bash
./run.sh      # compila y abre la app
swift test    # los 250 tests del núcleo
```

Eso es todo lo que hace falta para verla funcionando. La firma, el empaquetado
del disco y el modo maqueta —datos de muestra en memoria para revisar el diseño
sin tocar los tuyos— tienen su propio capítulo:

**[Compilar, firmar y empaquetar →](docs/compilar.md)**

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

### Por qué no hay cuentas

Pauta no tiene registro ni inicio de sesión, y no es un descuido: **no hay a
dónde entrar**. Un login solo significa algo si hay un servidor que guarda tus
datos o una suscripción que comprobar, y aquí no hay ninguna de las dos. Los
datos son tuyos, están en tu carpeta, y la cuenta que los sincroniza ya existe:
es la Apple Account de tu iCloud. Añadir otra sería una segunda identidad para
la misma persona, y la app tendría que decidir qué hacer cuando las dos no
coincidan.

Las reglas de la App Store empujan en esa misma dirección. La 5.1.1(v) dice que
una app no puede exigir cuenta para funciones que no dependen de una cuenta, así
que una pantalla de registro delante de un gestor de tareas local es más
probable que se rechace a que se pida. Y si algún día se ofreciera un login de
terceros —Google, por ejemplo—, la 4.8 obliga a ofrecer también una alternativa
equivalente que no recopile datos, que es justo lo que hace *Iniciar sesión con
Apple*: Google a secas no sería una opción.

Un login se justificaría el día que haya algo al otro lado: **compartir listas
con otra persona**, una versión web, sincronizar con algo que no sea Apple, o una
suscripción con derechos que verificar. Ni siquiera cobrar por la app lo exige —
de eso ya se encarga el recibo de compra. Si llega, lo razonable es *Iniciar
sesión con Apple* y como **llave de lo compartido, nunca como puerta de entrada**:
la app tiene que seguir abriéndose y funcionando entera sin identificarse.

### Lo que sí costaría publicarla

El trabajo de llevarla a la App Store no son las cuentas, es el **sandbox**: allí
es obligatorio, y bajo sandbox la ruta de ahora
—`~/Library/Mobile Documents/com~apple~CloudDocs/Pauta/`— deja de ser accesible.
Habría que pasar al contenedor de iCloud de verdad, con sus entitlements y su
perfil, que es exactamente lo que este montaje evitaba. Con `NSUbiquitousContainers`
la carpeta sigue viéndose en iCloud Drive, así que no se pierde nada de cara al
usuario, pero **la ruta cambia** y los datos hay que mudarlos.

Lo bueno es que esa mudanza ya está resuelta: `adoptData(from:to:)` es lo que hace
hoy al estrenar la carpeta de iCloud —copia lo que hubiera en la local y deja el
original como respaldo—, y sirve igual para el salto al contenedor. Lo demás es
fontanería conocida: proyecto de Xcode en vez del bundle a mano, firma de
distribución, notarización y las etiquetas de privacidad.

### Y si algún día se cobrara

La misma decisión que la de las cuentas, vista desde el otro lado: **ni por
número de proyectos ni por asiento**, sino una compra única.

Cobrar por cantidad —tantos proyectos, tantas tareas— es lo que primero se le
ocurre a cualquiera y es lo peor que le podría pasar a esta app. Castiga justo a
quien le está funcionando, que es el que ha metido su vida dentro, y lo hace en
el peor momento: cuando ya no puede volverse atrás sin dolor. Peor todavía,
cambia cómo se usa: con dos proyectos de margen se duda antes de crear uno, y un
gestor de tareas en el que dudas antes de apuntar algo ha dejado de hacer su
trabajo. Sería cobrar por empeorar el producto. Y hay algo que el usuario huele
aunque no sepa explicarlo: **los costes de aquí no crecen con sus proyectos**.
Sin servidor, el proyecto número cuarenta cuesta lo mismo que el primero, que es
cero.

Por asiento tampoco, mientras no haya equipo: sería cobrar por algo que no
existe. Pero el día que haya compartir, por asiento **es** lo correcto, y por
suscripción — porque ahí aparece por fin la única parte con coste real y
recurrente, y el precio sigue al coste. Que es lo mismo que pasa con el login:
[la cuenta y la suscripción llegan juntas o no llegan](#por-qué-no-hay-cuentas).

Mientras tanto, una compra única y el recibo de la App Store como única llave:
no hay nada que se pueda dejar de pagar porque no hay nada que haya que seguir
pagando. Con prueba de verdad y no con recortes — nadie muda su vida a un gestor
de tareas por una captura de pantalla, hay que vivir con él una semana: gratis y
completa ese tiempo, y luego se paga para seguir. No se quitan funciones, se da
tiempo.

Si hicieran falta dos escalones, el corte honesto no es «tres proyectos o
ilimitados», es **«tu Mac» contra «tu vida en todos lados»**: macOS completo, y
la compra trae iPhone, widget e integraciones. Ese límite se entiende sin
explicarlo, y encima es el que de verdad cuesta mantener.

Y una regla para entonces: **sin servidor, se cobra por versión mayor y no por
mes**. Es lo único que paga el mantenimiento sin pedirle a nadie que alquile algo
que no cuesta nada.

Copiar la carpeta es la copia de seguridad; borrarla deja la app a cero. Para ver
el estado guardado sin abrir la interfaz:

```bash
./build/Pauta.app/Contents/MacOS/Pauta --dump
```
### Cómo funciona por dentro

Por qué un archivo por objeto, cómo se ordena la lista sin reescribirla entera,
cómo se resuelve un conflicto entre dos dispositivos y por qué la decodificación
tiene que ser tolerante:

**[Cómo se guarda y cómo se sincroniza →](docs/tecnica.md)**

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
| `ios` | La lámina del teléfono: a sangre, sin margen ni esquinas |
| `reloj` | La del reloj: igual, pero con el monograma más pequeño — la máscara de watchOS es un **círculo**, y un círculo come más que el redondeo de iOS |

```bash
python3 tools/make-icon.py ambas   # los .icns del Mac y los catálogos de iOS y reloj
ICONO=icon-claro ./build.sh
```

Al ser un monograma y no un wordmark, el mismo arte funciona de 16 a 1024 px sin
necesitar versiones distintas por tamaño.

Las dos láminas del Mac llevan **squircle con margen transparente**, que es la
forma del icono en macOS y la dibuja la app. La de iOS es lo contrario: el color
llega al borde y la máscara la pone el sistema. Poner la del Mac en el teléfono
se vería como un icono dentro de un marco, con un borde muerto alrededor.

Y va en un catálogo de recursos con **una sola imagen de 1024**, no en quince
tamaños: desde Xcode 14 el sistema los deriva, y mantener quince a mano era
garantizar que alguna se quedara con el arte viejo. En la ruta del simulador, que
no pasa por Xcode, lo compila `actool`.

### Limitación conocida del arte actual

El monograma se extrajo de un *mockup* con fondo, sombras y resplandor
incrustados, filtrando por color y quedándose con las componentes conexas
grandes. Funciona, pero a 512 px se aprecian dos defectos: una muesca en el brazo
de la P y un fragmento de la línea oscura que separa el check en el diseño
original — un detalle de tres colores que una extracción a dos no puede
representar. A tamaño de Dock (128 px) no se ven.

Con un SVG o un PNG a 1024+ con fondo transparente se regenera todo perfecto en
un comando: sustituye `Resources/monogram.png` y ejecuta `make-icon.py`.
## Estructura

```
Sources/PautaCore/        librería sin UI: la comparten macOS, iOS y el widget
  Models.swift            Item, ChecklistStep, Project, Area, Perspective
  Store.swift             estado + persistencia + consultas
  Avisos.swift            avisos del sistema para las tareas con hora
  Agenda.swift            eventos del calendario, solo de lectura
  Hoy.swift               agrupar Hoy por proyecto, y cuánto queda de cada uno
  Pliegue.swift           qué grupos cerraste hoy, y que mañana se abren solos
  Cuenta.swift            cuánto falta para lo siguiente
  Duracion.swift          cuánto dura cada cosa y cuánto suma el día
  Cuando.swift            el día y la hora que trae escritos una tarea
  Ajustes.swift           las preferencias, en UserDefaults
  Paleta.swift            los colores en crudo, que usan las dos interfaces
  Enlaces.swift           las direcciones, que son las mismas en las dos apps
  PuestaAPunto.swift      qué permisos se ofrecen al usuario nuevo
  Despacho.swift          las decisiones del vaciado de la bandeja
  Atajo.swift             una combinación de teclas y si sirve como atajo
  Repaso.swift            el repaso de la mañana
  Vistazo.swift           lo que cabe en un widget, y de dónde se lee
  Orden.swift             lo que el reloj le pide al teléfono
  Puente.swift            cruzar dos carpetas: gana la versión más reciente
  CarpetaElegida.swift    el marcador de la carpeta que elegiste, y si caducó
                          —el almacén en iOS, una instantánea en el Mac—
Sources/Pauta/            la app de macOS
  PautaApp.swift          punto de entrada, menús, atajos y barra de menús
  AltaRapida.swift        atajo global y panel para apuntar sin abrir la app
  Views/Theme.swift       paleta, tipografía y filetes
  Views/SidebarView.swift barra lateral
  Views/ItemListView.swift lista y cabecera
  Views/ItemRowView.swift fila, casilla y editor desplegado (Liquid Glass)
  Views/GrupoRow.swift    la cabecera de un proyecto en Hoy, con su filete
  Views/PapeleraView.swift lo borrado, y el botón de devolverlo
  Views/MenuBarView.swift panel de la barra de menús y cuenta atrás
  Views/AcercaDe.swift    el panel «Acerca de» y los enlaces
  Views/Ayuda.swift       atajos y estado de los permisos
  Views/AjustesView.swift ajustes y arranque al iniciar sesión
  Views/PuestaAPuntoView.swift la tarjeta de bienvenida
  Views/VaciarBandejaView.swift el vaciado, con teclado
  Views/GrabadorDeAtajo.swift  grabar una combinación y nombrar las teclas
Sources/PautaIOS/         la app de iOS: su propia interfaz, el mismo núcleo
  Tema.swift              la paleta compartida, resuelta con UIKit
  PautaIOSApp.swift       punto de entrada y las cuatro pestañas
  ListaView.swift         una lista, con su título y su vacío
  FilaView.swift          la fila y sus marcas
  GrupoFila.swift         la cabecera de un proyecto en Hoy, con su filete
  PapeleraView.swift      lo borrado, y devolverlo deslizando
  Captura.swift           el botón flotante y el campo de apuntar
  Apuntar.swift           el atajo de Siri: apuntar sin abrir la app
  EventoRow.swift         un evento del calendario en la lista
  AjustesView.swift       ajustes, permisos y acerca de
  PuestaAPuntoView.swift  la tarjeta de bienvenida
  MasView.swift           listas de fondo, proyectos, áreas y etiquetas
  DetalleView.swift       la ficha de una tarea
Sources/PautaWidget/      el widget de iOS: otro proceso, y solo lectura
  PautaWidget.swift       el paquete de widgets y su línea de tiempo
  HoyView.swift           lo que se dibuja, por tamaño
Sources/PautaWatch/       el reloj: enseña el vistazo del teléfono y le pide tachar
  PautaWatchApp.swift     punto de entrada
  EnlaceConElTelefono.swift  lo que llega por WatchConnectivity, y lo que se pide
  ApuntarDesdeElReloj.swift  el atajo de Siri en la muñeca
  HoyWatchView.swift      el día, a la altura del brazo, con su círculo para tachar
Sources/PautaWatchWidget/ la complicación: lee lo que la app del reloj dejó escrito
  PautaWatchWidget.swift  el paquete y su línea de tiempo
  EsferaView.swift        cada forma de la esfera, por separado
Sources/PautaWidgetMac/   el widget del Mac: lee la instantánea, no los datos
  PautaWidgetMac.swift    el paquete, la línea de tiempo y el día que descarta
  HoyViewMac.swift        lo que se dibuja, por tamaño
Tests/PautaCoreTests/     tests del núcleo (swift test)
build.sh · run.sh         compilar el Mac y relanzarlo
tools/xcode.sh            dónde está Xcode, buscándolo en vez de escribiéndolo
tools/ios.sh · iphone.sh  el simulador y un iPhone de verdad
tools/make-dmg.sh         el disco de descarga
tools/make-icon.py        los iconos, del mismo arte
docs/ios.md               el capítulo del teléfono
docs/compilar.md          compilar, firmar, empaquetar y el modo maqueta
docs/tecnica.md           persistencia, orden, sincronización y decodificación
```

## Qué falta (siguiente iteración)

- **Los eventos también en `Próximamente`**, que ya va agrupada por día y es
  donde encajarían sin inventar nada. Se dejó fuera para no cargar de golpe una
  ventana de semanas de calendario: primero conviene ver si en `Hoy` estorban o
  ayudan
- **La sincronización automática en el teléfono.** Entrar en iCloud como lo hace
  el Mac exige el contenedor de ubicuidad, y eso **lo cierra la cuenta**:
  comprobado pidiéndoselo a Apple, «*Personal development teams do not support
  the iCloud capability*». Lo que sí hay es el
  [puente](docs/ios.md#el-puente-con-el-mac): eliges la carpeta del Mac una vez
  y el teléfono cruza con ella al volver a la app. Falta que sea automático de
  verdad, sin elegir nada y sin volver a la app
- **Notarizar el disco**, que es lo que quitaría el paso de la cuarentena al
  instalar. Hace falta un certificado *Developer ID*, y ese lo da el **programa
  de pago** de Apple: con esta cuenta personal no hay ninguno en el llavero ni
  forma de crearlo

## Licencia

**Código a la vista, no de código abierto.** El repositorio es público para que se
pueda leer, estudiar y comprobar qué hace la app con tus datos — que en una app
que guarda tu vida en archivos sueltos es lo menos que se puede ofrecer. Pero no
es de dominio público: ver los [términos](LICENSE).

**Puedes** leerlo, estudiarlo, **compilarlo y usarlo en tus propios equipos**,
cambiarlo para ese uso tuyo, y proponer cambios aquí.

**No puedes** copiarlo, redistribuirlo ni venderlo; publicar obras derivadas,
adaptaciones o bifurcaciones para distribuir —tampoco con otro nombre y otro
diseño—; meter ninguna parte en otro producto o servicio; ni usarlo para
**entrenar modelos**. Para cualquiera de esas cosas hace falta permiso escrito.

Esa última no es una manía: hoy el mayor destino de un repositorio público es
acabar en un corpus de entrenamiento, y quien lo hace no pide permiso a nadie.
Prohibirlo puede no detener a quien ya raspa sin mirar la licencia, pero deja
dicho que no había permiso.

Y al revés: los **cambios que propongas** aquí quedan licenciados al titular para
usarlos en el programa. Sin esa línea, aceptar una mejora ajena dejaría un trozo
del código con dueño distinto al resto y sin permiso claro para venderlo algún
día.

Para pedir permiso o preguntar: [@jadrdev](https://github.com/jadrdev), o
[abriendo una incidencia](https://github.com/jadrdev/pauta/issues).

### Por qué no MIT

Estuvo bajo MIT hasta el 4 de septiembre de 2026, y se cambió por lo que la MIT
permite: coger esto, cambiarle el diseño, ponerle otro nombre, cerrarlo y
venderlo, cumpliendo solo con dejar el aviso de copyright en un archivo que
nadie abre. Es una licencia que está bien para una biblioteca que quieres que
acabe en todas partes, y no para una app que igual algún día se
[cobra](#y-si-algún-día-se-cobrara).

Tampoco vale una copyleft aquí. La GPL obligaría a abrir las modificaciones,
pero **no impide el clon con otro nombre** —solo lo obliga a ser abierto
también—, y encima es incompatible con la App Store, que es justo el sitio donde
esto podría acabar.

Un cambio de licencia **no se aplica hacia atrás**: quien tuviera el código antes
de esa fecha lo conserva bajo la MIT para esa versión. No hay forma de retirar un
permiso ya dado, y pretender lo contrario sería mentir. Lo que rige de aquí en
adelante es el aviso nuevo.

Y como siempre: **sin garantía de nada**, que aquí los datos son tuyos y el que
responde por ellos también.

Hecho por [@jadrdev](https://github.com/jadrdev) · © 2026 Joshua A. Díaz Robayna
