# Compilar, firmar y empaquetar

Todo lo que hace falta para construir Pauta uno mismo. Qué hace la app y por qué
está en el [README](../README.md); el teléfono, en [su capítulo](ios.md).

## Compilar y ejecutar

```bash
./run.sh
```

Compila y abre la app. Solo `./build.sh` genera `build/Pauta.app` sin lanzarla —
puedes arrastrarla a `/Applications` cuando te guste cómo va. `ICONO=icon-claro
./build.sh` usa la otra lámina de icono.

```bash
swift test
```

Los tests cubren `PautaCore`, que no depende de la interfaz.

Hace falta **XcodeGen** (`brew install xcodegen`), y esto es nuevo: `build.sh`
era `swift build` más un paquete montado a mano, y ahora pasa por el proyecto de
Xcode. Lo obligó el **widget**, por dos razones que ninguna herramienta de
paquetes cubre:

- Una extensión no es un binario más dentro del paquete: es **otro paquete**
  —con su identificador, sus permisos y su punto de extensión— embebido en
  `Contents/PlugIns/` y firmado aparte.
- Un **grupo de aplicaciones** necesita que la firma vaya autorizada, y quien
  pide esa autorización a Apple es Xcode.

El `.xcodeproj` no se guarda: se declara en [`project.yml`](../project.yml) —un
pbxproj son miles de líneas generadas que se llenan de conflictos y que nadie
lee—. Un solo proyecto para las dos plataformas, con el núcleo como objetivo
propio en cada una: dependiendo del paquete, Xcode intentaría compilar todos sus
objetivos para el destino equivocado.

## Firma

Firma Xcode, con **firma automática** y el equipo escrito en `project.yml`:
`26W4G92PSS`, el personal.

Antes lo hacía `build.sh` a mano, cogiendo «la primera identidad *Apple
Development* del llavero que no estuviera revocada». Y esa resultó ser la del
**trabajo** —`L6BPFFM8F3`, otra empresa—, sin que nadie lo hubiera decidido: la
app personal llevaba meses firmada con el certificado de la empresa porque salía
antes en la lista. Se descubrió al montar el widget, porque en macOS el grupo de
aplicaciones lleva el identificador del equipo delante y la elección deja de ser
invisible:

```
com.apple.security.application-groups = [ 26W4G92PSS.dev.jadrdev.pauta ]
```

El cambio de equipo se paga una vez: el requisito designado fija el certificado
por su nombre, así que para el sistema la app pasó a ser otra y volvió a pedir
los permisos —calendario, recordatorios, avisos y el arranque al iniciar sesión—.

No es un detalle cosmético. Con firma ad-hoc el hash del binario cambia con cada
cambio de código, y TCC —el sistema de permisos— identifica las apps por su
firma: cada build sería una app nueva para el sistema, así que los permisos de
calendario, recordatorios o accesibilidad se pedirían otra vez en cada
compilación, dejando entradas basura en Ajustes de Privacidad.

Con una identidad de desarrollador el requisito designado pasa a basarse en el
identificador y el certificado, y **eso** es lo que sobrevive a recompilar:

```
designated => identifier "dev.jadrdev.pauta" and anchor apple generic
              and certificate leaf[subject.CN] = "Apple Development: …"
```

Comprobado: tras un cambio real de código el `cdhash` cambia y ese requisito no,
así que los permisos concedidos sobreviven a las recompilaciones. Esto es lo que
desbloquea las integraciones con Calendario y Recordatorios.

La letra pequeña: los certificados «Apple Development» caducan (el actual, en
mayo de 2027). Cuando caduque habrá que renovarlo y volver a conceder permisos.

### Una sola copia

Y algo que costó encontrar: **el permiso de avisos es de cada copia, no de la
app**. Con `Pauta.app` en Aplicaciones y otra compilada en `build/`, macOS deja
arrancar las dos —mismo identificador, misma firma, misma versión— y las trata
como dos:

```
$ /Applications/Pauta.app/Contents/MacOS/Pauta --avisos
app: /Applications/Pauta.app
permiso de avisos: notDetermined      avisos programados: 0

$ ./build/Pauta.app/Contents/MacOS/Pauta --avisos
app: /Users/…/build/Pauta.app
permiso de avisos: authorized         avisos programados: 4
```

Con las dos abiertas hay dos iconos en la barra de menús, dos apps peleándose
por el atajo global, dos vigilantes escribiendo en la misma carpeta, y una que
dice «los avisos están desactivados» mientras el sistema los da por activados
—porque los activó la otra—.

Ahora la segunda copia **cede**: trae al frente a la que ya estaba y se va, como
cualquier app de macOS. Y `--avisos` empieza diciendo de qué paquete habla, que
es la línea que faltaba para ver esto en un segundo en vez de en media hora.

Y al revés, también medido: copiar encima de Aplicaciones **el mismo binario**
que ya tenía el permiso lo trae con él, y la copia instalada pasó a decir
`authorized` sin volver a preguntar nada. Así que lo que mira el sistema no es
el identificador —dos copias daban respuestas distintas— pero tampoco solo la
ruta. No se documenta aquí una teoría de cómo lo decide Apple; se documenta lo
que se puede comprobar con dos comandos, que es lo único que sirve el día que
vuelva a pasar.

### Qué Xcode se usa

No hace falta abrirlo, pero sí tenerlo instalado: de ahí salen `xcodebuild`, los
SDK y la firma. Los guiones lo **buscan**, en [`tools/xcode.sh`](../tools/xcode.sh),
por este orden:

1. `DEVELOPER_DIR`, si ya viene puesto — manda quien llama, y es lo que permite
   compilar con otra versión sin editar nada.
2. Lo que diga `xcode-select`, **solo si apunta a un Xcode**. Si apunta a las
   Command Line Tools no sirve para compilar apps, y ese es el caso que trajo
   todo esto.
3. El primer Xcode de `/Applications`, con la beta al final: si están las dos,
   la estable es la que firma lo que se publica.

Antes de eso, los guiones llevaban escrito `/Applications/Xcode-beta.app`. Era
la ruta de **una app concreta**, y el día que la beta se desinstaló se rompieron
los cinco a la vez con el mismo error:

```
xcrun: error: missing DEVELOPER_DIR path: /Applications/Xcode-beta.app/…
```

Si no encuentra ninguno, lo dice y para, en vez de fallar más adelante con un
error sobre rutas que nadie escribió.

## Empaquetar el disco

```bash
./tools/make-dmg.sh
```

Monta el `.dmg` con la app y un enlace a `Aplicaciones`. Avisa de si la firma
sirve para repartir o solo para probar, y escupe el sha256 para poder publicarlo
junto al archivo. Los detalles de por qué hace falta quitarle la cuarentena están
en [Instalar](../README.md#instalar).

## Modo maqueta

Para revisar el diseño sin tocar tus datos reales: arranca con tareas de muestra
en memoria, que no se escriben en disco, y permite forzar la apariencia.

```bash
./build/Pauta.app/Contents/MacOS/Pauta --demo --light
./build/Pauta.app/Contents/MacOS/Pauta --demo --dark --view 3
```

`--view 1…6` elige la lista de arranque, en el orden de la barra lateral.
Combinado con `--dump` inspecciona la maqueta en vez de los datos reales.

`--vistazo` dice qué le ha dejado escrito la app al widget: la carpeta del
grupo, de qué día es la instantánea y qué filas lleva. Existe porque desde fuera
no se puede mirar —la carpeta de un grupo está protegida por el sistema y un
terminal no entra ahí—, y sin él la única forma de saber si el widget tiene algo
que enseñar sería mirar el widget.

`--alta-rapida` abre el panel del atajo al arrancar. Está para poder mirarlo y
comprobar que el foco cae en el campo sin inyectar el atajo por debajo: un
⌃Espacio sintético obliga a que el foco salte entre apps, y eso ni prueba lo que
hay que probar ni sale gratis.

---

[← Volver al README](../README.md)
