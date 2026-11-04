# Validación actual · Etapa 2 ampliada · 31 octubre 2026

Las secciones anteriores se conservan abajo como historial. Implementación, fórmulas y los 33 puntos de entrega: [docs/STAGE2_IMPLEMENTATION.md](docs/STAGE2_IMPLEMENTATION.md).

- Inspección inicial: AppStore/ChangeNotifier con Riverpod, go_router de cuatro destinos, SQLite v3, funcionalidades de Etapa1 y primer módulo de análisis/PDF. Sin Git. Flutter3.47.7/Dart3.13.5; doctor sin problemas; análisis inicial limpio y63 pruebas aprobadas. Proyecto Kotlin original consultado sin modificarlo.
- `dart format .`: aplicado. `flutter pub get --offline`: correcto usando dependencias instaladas, repetido después de limpiar para dejar el editor preparado.
- `flutter analyze --no-pub`: **No issues found**. Evidencia: tmp/analyze.log.
- `flutter test --no-pub --concurrency=1`: **90 pruebas aprobadas**, 27 más que al inicio, incluidas migraciones v2/v3→v4, protección de importaciones, entrenamiento/convergencia/gradiente, ausencia de fuga temporal, persistencia de dos modelos e invalidación, JSON, apoyo, PDF y widgets. Evidencia: tmp/tests-final.log.
- Revisión visual con capturas reales de widgets, fuentes locales y datos sintéticos: **4 pruebas aprobadas**. Nueve PNG: Resumen, Tendencias, Actividades, Sueño/pasos, Dispersión, Predicción, Reportes, oscuro/texto1.4 y vacío. Las pruebas anteriores también cubren320×640. Se corrigieron las fuentes de ejes/botones detectadas al inspeccionar imágenes. Se abren métricas y explicación de contribuciones en la prueba. Evidencia: tmp/visual.log y docs/screenshots/stage2-*.png.
- PDF ficticio de muestra: output/pdf/moodwave-demo.pdf, **3 páginas A4, 25,882 bytes**. Todas renderizadas con Poppler e inspeccionadas; sin recortes, tablas fuera de página ni emojis rotos. Incluye media/mediana/modas/desviación poblacional y rachas. Los tests prueban PDF con/sin salud, semanal/mensual, reflecciones excluidas por defecto y predicción opcional. Imágenes intermedias retiradas al terminar.
- Modelo real reproducible solo sintético: 85 ejemplos;68 entrenamiento/17 prueba. Accuracy modelo82.35%, balanceada82.86%; baseline47.06%/46.43%. Supera la referencia en ese dataset, sin validez clínica ni promesa de generalización. Convergencia estricta no alcanzada en ese benchmark:1200 iteraciones, pérdida0.693147→0.372504; la prueba independiente confirma que el criterio de convergencia sí detiene antes del límite cuando corresponde. Evidencia: output/model-evaluation.json.
- Build final correcto: `flutter build apk --debug --flavor trial --split-per-abi --target-platform android-arm64 --no-pub`. Último build69.2s. Las advertencias de Java/SDK XML no impidieron la compilación. Evidencia: tmp/build-final.log.
- `aapt dump badging`: **com.example.moodwave.trial**, launcher **MoodWave Prueba**, versionCode1, versionName1.0.0-trial, minSdk**26**, target/compileSDK**36**, única ABI**arm64-v8a**. USE_BIOMETRIC/USE_FINGERPRINT conservados; READ_SLEEP/READ_STEPS incorporados. force-version-code-ignoring-abi evita que un APK split cambie el código y obligue a desinstalar al seguir usando flutter run.
- APK conservado: **artifacts/apk/moodwave-trial-debug.apk**, **111,815,930 bytes (106.64MiB)**. SHA-256: **41DB037D4B31D044F8A2A35C6AAE1BC884BD4675604A34FD8451D00BC821758F**. Hash idéntico al generado antes de limpiar. El APK universal intermedio (146.27MiB) fue sustituido; solo se conserva el final ARM64.
- Instalación final Huawei DUB-LX3/API27, serial5XJRX19509005779: `adb install -r` → **Success**. No se desinstaló ni se borraron datos. El proceso de la compilación anterior del mismo código permaneció abierto y sin errores AndroidRuntime/flutter en el filtro consultado, pero am start-W agotó su espera de primer dibujo; eso no acredita navegación interactiva. Tras instalar el APK ARM64 final, el teléfono dejó de aparecer por ADB antes de repetir el arranque. No se afirma validación física final de huella, PIN, migración visible, exportación o compartir.
- Limpieza verificada dentro del workspace: `flutter clean` retiró build/.dart_tool y generados; se retiraron solo PNG temporales de PDF. Aproximadamente**1.89GiB de archivos regenerables** retirados. Disco C quedó con**33.15GiB libres** al medir. No se borraron SDK, cachés compartidas, código, datos del teléfono ni el proyecto Kotlin. Dependencias restauradas offline para continuar modificaciones.
- Health Connect es integración nativa real compilada con SDK1.1.0: proveedorAPI28+, captura manualAPI27. Pendiente prueba física de concesión/denegación/revocación/importación en un equipo compatible. No existe simulación de lecturas o permisos. Manual, protección de datos y estados de UI tienen pruebas automatizadas.
- Pendiente con el usuario: abrir MoodWave Prueba, verificar registros anteriores, repetir PIN/huella/bloqueo; editar un día sin salud y con salud; comprobar PDF/JSON mediante selector y compartir voluntariamente. Para demostración: Configuración→generar/regenerar prueba; Patrones→Predicción→Modo demostración→Entrenar. Eliminar solo sintéticos si se desea conservar únicamente datos personales.

---

# Validación — 30 de octubre de 2026

## Entorno

- Flutter 3.47.7 estable; Dart 3.13.5.
- `flutter doctor`: sin problemas; Android SDK 36.0.0 disponible.
- `flutter devices`: Windows, Chrome y Edge. Sin Android conectado.
- `flutter emulators`: no hay emuladores configurados.
- Las dependencias fueron resueltas y descargadas mediante `flutter pub add`; sus versiones exactas están bloqueadas en `pubspec.lock`.

## Comprobaciones

- `dart format lib test`: aplicado.
- `flutter analyze`: **No issues found**.
- `flutter test`: **23 pruebas aprobadas**.
- `flutter build apk --debug`: APK debug generado correctamente, incluido MainActivity Kotlin con FingerprintManager.
- Inspección con `aapt dump badging`: applicationId `com.example.moodwave`; versionName `1.0.0`; minSdk **24**; targetSdk **36**; compileSdk **36**; permisos USE_BIOMETRIC y USE_FINGERPRINT presentes.
- APK: `C:\Users\soria\FlutterProjects\MoodWave\build\app\outputs\flutter-apk\app-debug.apk`.

## Cobertura efectiva

Pruebas unitarias: normalización local y UTC, clave diaria, promedios, emoción frecuente, mejor día y desempates, rachas al cruzar año, días únicos, límites de semana/mes, estados sin datos, validación de PIN y derivación PBKDF2 con salt.

SQLite real mediante FFI: persistencia al cerrar/reabrir archivo, actualización sin duplicar, consulta por id/fecha, generación de 90 días sin sobrescritura, borrado de pruebas y borrado individual/total. Las pruebas usan la creación de esquema del repositorio de producción.

Widgets: ocho emociones, límite de reflexión, estado vacío, cambio semanal/mensual, confirmación de eliminación, puerta de seguridad, bloqueo al volver del segundo plano, editor de 320×568, creación confirmada del PIN y desbloqueo con PIN. El almacenamiento seguro y la biometría se simulan únicamente en estas pruebas. La derivación criptográfica se ejecuta realmente.

## Límites de lo verificado

El inicio y los flujos de interfaz se ejecutaron en el motor de pruebas de Flutter. No se ha iniciado ni instalado el APK en un Android físico o emulado porque no hay ninguno disponible. La compilación correcta no confirma la huella real del Huawei: hay que probar API 27 con FingerprintManager y API 28+ con local_auth. iOS tampoco se compiló en Windows.

El CSV se guarda en documentos privados y muestra su ruta; aún no existe una hoja para compartirlo. No hay migración automática desde Room, sincronización ni respaldo cifrado. La base SQLite usa el aislamiento del sistema, sin cifrado adicional de su contenido.

Gradle emitió advertencias de acceso nativo de Java 25 y de lectura de metadatos SDK de distinta versión. No impidieron generar el APK.

## Validación física de la variante trial

Se conectó un Huawei DUB-LX3, Android 8.1/API 27, ARM64. Se añadió la variante Android `trial`, identificador `com.example.moodwave.trial`, etiqueta `MoodWave Prueba`, conservando `production` con el identificador original.

- `flutter analyze`: sin incidencias tras configurar los sabores.
- `flutter build apk --debug --flavor trial --target-platform android-arm64`: correcto.
- `aapt dump badging`: identificador trial y nombre independiente confirmados; minSdk 24 y targetSdk 36.
- Instalación ADB: Success.
- Se confirmó que `com.example.moodwave` y `com.example.moodwave.trial` siguen instalados en rutas independientes.
- La primera llamada `am start -W` agotó su espera; la comprobación posterior confirmó actividad reanudada, proceso activo y ventana enfocada en la variante trial.
- Captura física: `docs/screenshots/huawei-trial-start.png`, pantalla de confirmación del PIN visible en el Huawei.
- No se observaron errores AndroidRuntime/flutter en los registros del proceso revisados.
- No se automatizó ni se leyó el PIN del usuario. Huella, persistencia y recorrido completo en el dispositivo siguen pendientes de prueba manual.

APK de prueba: `build/app/outputs/flutter-apk/app-trial-debug.apk`. La validación inicial anterior se conserva como historial; el arranque físico ya fue comprobado con esta variante.

### Huella confirmada por el usuario

El usuario confirmó que la autenticación biométrica funcionó en MoodWave Prueba instalada en el Huawei DUB-LX3, Android 8.1/API 27. En esta API, BiometricService selecciona el canal nativo con FingerprintManager; queda validado el desbloqueo por huella en ese teléfono según la prueba manual del usuario. Esta confirmación no cubre cancelación, errores de reconocimiento, bloqueo del sensor ni dispositivos modernos/iOS.

## Limpieza conservadora del proyecto

Se ejecutó `flutter clean` únicamente en la carpeta Flutter. Se eliminaron build, .dart_tool y configuración efímera generada. Antes de hacerlo, se copió el APK trial a `artifacts/apk/moodwave-trial-debug.apk` y se verificó que su SHA-256 coincidiera con el original. Esta carpeta de binarios está excluida de Git.

Después se ejecutó `flutter pub get --offline` para restaurar la configuración ligera de edición. No se borraron SDK, NDK, imágenes Android, cachés compartidas de Gradle/Pub/Flutter, el proyecto Kotlin ni datos del teléfono.

Medición del disco tras la limpieza: aproximadamente 3.59 GiB recuperados y 22.66 GiB libres en C:. El espacio libre puede variar por otros procesos de Windows. La próxima compilación regenerará sus archivos temporales.

## Rediseño de la experiencia diaria

Implementado un recorrido de tres pasos (Sentir/Vivir/Recordar), esfera emocional con transición, selector adaptable de ocho emociones, batería visual de energía, iconos y respuesta háptica en actividades, sugerencias de escritura no destructivas, confirmación mediante tarjeta del día y resumen semanal. Se renovaron los encabezados con ondas dibujadas, el acceso con PIN, la navegación, el avatar de perfil y la distribución de tarjetas de estadísticas. No se añadió ninguna dependencia ni se cambió el esquema de datos.

La comprobación visual se hizo con capturas generadas en el motor Flutter y datos ficticios. Incluye tema oscuro y texto al 160 %. Se corrigieron los desbordamientos en el selector compacto, la superposición de mensajes sobre el botón principal y la posición de desplazamiento al volver a editar. La configuración de accesibilidad para reducir animaciones desactiva las transiciones nuevas.

Pruebas añadidas en `test/journey_test.dart`: recorrido y conservación de selecciones al retroceder, guardado de todos los campos, regreso a edición con la reflexión conservada y recorrido con letra grande/tema oscuro. Las capturas opcionales se regeneran con `flutter test test/journey_test.dart --dart-define=CAPTURE_UI=true` en el entorno Windows de desarrollo; solo esta opción carga las fuentes locales para representar la vista previa.

Resultado final de validación del rediseño: `flutter analyze` sin incidencias y **25 pruebas aprobadas** con `flutter test`. Las dos pruebas de recorrido también pasaron con generación de capturas finales.

La actualización del rediseño se compiló una sola vez para `trial`/ARM64 y se instaló con `adb install -r` (Success) en el Huawei, conservando el identificador de prueba. La aplicación original permanece instalada. Tras la espera inicial de `am start -W`, se confirmó actividad reanudada y proceso activo de la variante trial, sin errores AndroidRuntime/flutter en los registros revisados. El recorrido completo renovado está probado en widgets; su valoración de uso en el teléfono corresponde a la prueba manual del usuario.

Al finalizar se reemplazó la copia conservada por el APK actualizado en `artifacts/apk/moodwave-trial-debug.apk` (aproximadamente 98.7 MiB), se verificó su copia por SHA-256 y se ejecutaron `flutter clean` y `flutter pub get --offline`. No quedó la carpeta build. Espacio libre medido al cierre: aproximadamente **24.15 GiB** en C: (puede variar por otros procesos de Windows). No se añadieron dependencias, fuentes ni imágenes a los recursos de la aplicación.

## Etapa 2 — resultados finales

- Base previa comprobada: Flutter 3.47.7, Dart 3.13.5 y flutter doctor sin problemas. Se preservó la aplicación existente; no hay Git en esta carpeta.
- SQLite v3: migración no destructiva desde v2 a daily_health_data; pruebas de conservación y rollback transaccional aprobadas.
- `dart format .`: aplicado.
- `flutter pub get --offline`: correcto.
- `flutter analyze --no-pub`: No issues found.
- `flutter test --no-pub --dart-define=GENERATE_SAMPLE=true`: **63 pruebas aprobadas**, incluidas Etapa 1 y nuevas pruebas de análisis, salud, migración, PDF y widgets.
- `flutter build apk --debug --flavor trial --target-platform android-arm64 --no-pub`: correcto. Una primera configuración falló por redeclarar la versión de un plugin Android ya cargado; se corrigió reutilizando el plugin disponible. No se descargó SDK 34: printing utiliza el SDK 36 instalado.
- AAPT: applicationId com.example.moodwave.trial, minSdk 24, targetSdk/compileSdk 36 y ambos permisos biométricos. No hay permisos de salud ni almacenamiento global añadidos. El permiso INTERNET del APK debug pertenece a las herramientas Flutter; las funciones implementadas son locales.
- APK final: artifacts/apk/moodwave-trial-debug.apk, **110,074,512 bytes** (aproximadamente 104.98 MiB). Solo se conserva esta copia actualizada, verificada por SHA-256.
- PDF de muestra: output/pdf/moodwave-demo.pdf, **25,690 bytes**, tres páginas. Generado con datos ficticios, revisado visualmente con Poppler y mediante extracción de texto con pypdf: acentos correctos, sin reflexiones por defecto, sin caracteres rotos ni texto cortado. Fuentes Roboto embebidas, sin descarga de fuentes en ejecución.
- Instalación Huawei DUB-LX3 API 27: adb install -r devolvió Success. Se confirmó proceso y actividad reanudada, y no se observaron errores AndroidRuntime/flutter en los registros revisados. Como en las aperturas previas, am start -W agotó su espera inicial; la comprobación posterior confirmó la actividad activa.
- El usuario confirmó físicamente que puede desbloquear, que aparece Patrones y que sus registros anteriores siguen presentes después de actualizar. La aplicación Kotlin original sigue instalada por separado.
- FingerprintManager permanece implementado y compila. Su funcionamiento en este Huawei fue confirmado por el usuario en Etapa 1; la confirmación actual de desbloqueo no identifica por sí sola qué método utilizó.
- Health Connect no está implementado; la captura manual funciona sin esa integración. Las fuentes imported/health_connect se prueban como valores persistidos, no como importadores reales.
- Pendiente de prueba manual en Huawei: edición de sueño/pasos, navegación de gráficos, vista previa de todas las páginas PDF, cancelar/guardar mediante Archivos, compartir por el menú del sistema y medir el pico real de RAM. No se afirma que estos flujos nativos hayan sido probados físicamente.
- Limpieza final: flutter clean y flutter pub get --offline. Se eliminaron build, .dart_tool temporal y las tres imágenes intermedias del PDF; se conservaron fuentes, código, herramientas compartidas, PDF de muestra y un APK. Espacio libre final medido en C: **23.97 GiB**. No se alteró el proyecto Kotlin de referencia.
- Memoria de compilación: heap Gradle 2 GiB, metaspace 768 MiB, dos trabajadores, sin paralelismo ni daemon persistente; Kotlin daemon 512 MiB. Vista previa PDF: una página a 72 dpi, liberando la imagen anterior. El consumo real del teléfono no fue perfilado.
