# Compilar, firmar y empaquetar

Todo lo que hace falta para construir Pauta uno mismo. Qué hace la app y por qué
está en el [README](../README.md); el teléfono, en [su capítulo](ios.md).

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

## Firma

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

`--alta-rapida` abre el panel del atajo al arrancar. Está para poder mirarlo y
comprobar que el foco cae en el campo sin inyectar el atajo por debajo: un
⌃Espacio sintético obliga a que el foco salte entre apps, y eso ni prueba lo que
hay que probar ni sale gratis.

---

[← Volver al README](../README.md)
