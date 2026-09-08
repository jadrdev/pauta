# Cómo se guarda y cómo se sincroniza

Las decisiones de dentro: por qué los datos son archivos sueltos, cómo se
resuelven los conflictos entre dos dispositivos y por qué la decodificación es
tolerante. La parte de fuera —qué hace la app y por qué— está en el
[README](../README.md); dónde vive la carpeta, en
[Dónde se guardan los datos](../README.md#dónde-se-guardan-los-datos).

## Por qué un archivo por objeto

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

## El orden de la lista

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

## Sincronización

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

**Y es incremental**: solo se abren los archivos que cambiaron. De cada uno se
recuerda su *sello* —fecha de modificación y tamaño— junto con lo que se leyó; si
el sello coincide, se reaprovecha lo de antes. El tamaño está en el sello porque
dos escrituras seguidas pueden caer en la misma fecha de modificación. Las claves
se piden en el propio listado del directorio, así que consultarlas no vuelve a
tocar el disco.

Importa porque el vigilante salta con **cualquier** escritura, incluidas las
nuestras: marcar una tarea como hecha releía la carpeta entera. Además, lo que se
acaba de escribir se anota en la caché en el momento de guardarlo, así que esa
recarga no abre ni un archivo. Con 500 tareas, veinte ciclos de escribir y
recargar pasan de 1,44 s a 0,12 s.

Preguntar por conflictos también se hace solo al releer un archivo, que era la
parte cara de la carga: un conflicto llega siempre acompañado de un cambio en el
archivo, así que no se pierde ninguno.

## Decodificación

Las tareas y los proyectos se leen con un `init(from:)` escrito a mano que usa
`decodeIfPresent` para todo. No es un capricho: el `Codable` sintetizado de Swift
usa `decode` para las propiedades no opcionales e **ignora sus valores por
defecto**, así que añadir un campo nuevo haría fallar la lectura de los archivos
ya guardados con un `keyNotFound`. Con el decodificador tolerante, los campos que
se añadan en el futuro no rompen los datos existentes.

---

[← Volver al README](../README.md)
