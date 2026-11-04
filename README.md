# MoodWave

**Etapa 2 ampliada (31/10/2026):** estadísticas completas, media móvil, dispersión, regresión logística local real, Health Connect nativo, exportación JSON y apoyo local. Documentación vigente: [implementación y entrega](docs/STAGE2_IMPLEMENTATION.md); resultados en [VALIDATION.md](VALIDATION.md). Las secciones históricas de rediseño documentan entregas anteriores.

Después de la limpieza de archivos regenerables, el APK de prueba conservado está en `artifacts/apk/moodwave-trial-debug.apk`. Las nuevas compilaciones seguirán generándose en `build/app/outputs/flutter-apk/`.

Diario emocional privado creado en Flutter, independiente del proyecto Kotlin de referencia situado en `C:\Users\soria\AndroidStudioProjects\MoodWave`. Ese proyecto se consultó en modo lectura; no se convirtió ni modificó.

## Abrir en VS Code

Instala las extensiones recomendadas Dart y Flutter. Abre esta carpeta, conecta un Android con depuración USB, selecciona el dispositivo y pulsa F5. La primera apertura solicita crear y confirmar un PIN de cuatro dígitos.

```powershell
flutter pub get
flutter devices
flutter run --flavor trial
```

Entorno utilizado: Flutter 3.47.7 estable, Dart 3.13.5, Android SDK 36, Java 17 o posterior compatible con Gradle. Android: `com.example.moodwave`, minSdk 26, compileSdk 36, targetSdk 36, Kotlin y embedding v2. El mínimo pasa a 26, autorizado para integrar Health Connect, y conserva Android 8.1/API 27. Las versiones resueltas están en `pubspec.lock`; no es necesario actualizarlas para abrir el proyecto. Los plugins de seguridad local resueltos declaran minSdk 24. iOS tiene su carpeta de plataforma y descripción Face ID, pero requiere macOS/Xcode para compilar y validar.

## Recorrido y diseño

- **Puerta de seguridad:** teclado propio, PIN oculto, creación con confirmación, desbloqueo, huella/rostro y mensajes accesibles.
- **Hoy:** ocho emociones, energía 1–10, actividades múltiples y personalizadas persistentes, reflexión de 300 caracteres y guardado/actualización local.
- **Calendario:** lunes a domingo, navegación mensual, celdas completas con fondo emocional y emoji, detalle, edición y eliminación confirmada.
- **Estadísticas:** semana/mes con navegación de periodos, promedios, cobertura, emoción frecuente, mejor día y evolución con tabla accesible de fechas y valores. No se inventan registros faltantes.
- **Perfil:** apodo, total, rachas, emoción/actividad frecuentes.
- **Configuración:** cambio confirmado de PIN en sesión desbloqueada, biometría, bloqueo, apariencia, exportación local CSV, borrado de pruebas y borrado total con doble confirmación, versión dinámica.

Material 3, turquesas suaves, tarjetas redondeadas, encabezados con ondas, temas claro/oscuro/sistema y animación breve de selección. Capturas de dispositivo pendientes de disponer de un Android conectado. Las pestañas conservan estado y borradores al alternar; la rotación la gestiona Flutter sin reiniciar la actividad. Las rutas de configuración y edición no muestran la barra inferior.

## Estructura

- `lib/main.dart`: inicialización local y ProviderScope.
- `lib/app/app.dart`: MaterialApp, temas, go_router, pestañas y ciclo de vida.
- `lib/app/state.dart`: dependencias Riverpod y controlador de sesión/datos.
- `lib/core/widgets.dart`: componentes visuales y confirmaciones.
- `lib/features/records/domain/record.dart`: modelo, emociones y fechas locales.
- `lib/features/records/data/record_repository.dart`: repositorio SQLite.
- `lib/features/records/presentation/editor.dart`: editor y reflexión.
- `lib/features/security/`: PIN, interfaz biométrica y pantalla de bloqueo.
- `lib/features/statistics/domain/statistics.dart`: cálculos puros.
- `lib/app/screens.dart`: calendario, estadísticas, perfil y configuración.
- `android/app/src/main/kotlin/com/example/moodwave/MainActivity.kt`: canal de huella heredada.
- `test/`: pruebas de dominio, SQLite real mediante FFI y widgets.

## Persistencia y privacidad

SQLite `moodwave.db` está en el directorio privado de bases de datos Android. El repositorio usa `dateKey` local `yyyy-MM-dd` con restricción UNIQUE. El guardado actualiza por fecha en una transacción y conserva el id. Actividades se serializan como JSON. `fecha` y `horaActualizacion` son milisegundos; `dateKey` determina el día. La versión actual es SQLite v3, con migraciones no destructivas v1→v2 (marcador isTest) y v2→v3 (tabla independiente de sueño y pasos). No se elimina la base al iniciar. El generador de 90 días se expone solo en debug y usa inserción con conflicto ignorado para no sobrescribir datos.

Las preferencias no sensibles (apodo, actividades y tema) usan shared_preferences. PIN y preferencia biométrica usan flutter_secure_storage. El PIN se deriva con PBKDF2-HMAC-SHA256, 210 000 iteraciones, salt aleatorio de 32 bytes y hash de 256 bits. La comparación acumula diferencias de bytes; no se guardan ni registran PIN en claro. Un único documento seguro conserva hash/salt/parámetros y solo se reemplaza después de confirmar el nuevo PIN. Tras cinco errores se aplica una espera de 30 segundos en la pantalla. Esta espera es local a la pantalla; no sustituye los controles del sistema.

El bloqueo se activa al recibir `paused` y evita reaccionar al estado `inactive` del diálogo biométrico. El PIN sigue disponible aunque falle la biometría. Borrar registros no elimina PIN ni preferencias. El backup automático Android está deshabilitado. La base SQLite no tiene cifrado adicional: usa el aislamiento del sistema; el PIN protege la interfaz de la app. No hay recuperación de PIN ni respaldo cifrado en esta etapa. Desinstalar borra los datos locales.

La versión Flutter **no migra automáticamente la base Room anterior**. Una instalación limpia no conserva sus registros. No se intenta leer la base interna Kotlin. Como ambas usan el mismo applicationId, no instales sobre la aplicación original si necesitas conservarla: usa otro dispositivo/perfil o prepara una migración y respaldo explícitos antes de reemplazarla.

La exportación CSV guarda un archivo sin cifrar en documentos privados de la app, muestra su ruta y requiere aceptar la exportación. En esta versión su recuperación se realiza con herramientas de desarrollo; no incorpora menú para compartir. No hay cuentas, servidor, Firebase ni sincronización. La información no sale automáticamente del dispositivo.

## Biometría

`BiometricService` puede sustituirse por una implementación falsa en pruebas. `device_info_plus` obtiene la API Android:

- API 23–27: canal `com.example.moodwave/legacy_fingerprint`, métodos `isAvailable`, `hasEnrolledFingerprints`, `authenticate`, `cancel`. Kotlin utiliza directamente FingerprintManager, verifica permiso/sensor/huellas y cancela con CancellationSignal. Cada intento responde una sola vez y descarta callbacks antiguos.
- Android API 28 o posterior e iOS: local_auth con autenticación exclusivamente biométrica.

Permisos Android: USE_BIOMETRIC y USE_FINGERPRINT, este último sin maxSdkVersion. FingerprintManager se conserva solo como fallback para API 23–27; el mínimo de instalación de la app es 24. La cámara **no se usa para autenticar rostros**. Face ID y reconocimiento facial dependen del hardware y de lo que la API del sistema exponga. No se usa ML Kit.

La compatibilidad física con Huawei Android 8.1 **requiere validación en ese dispositivo**. Compilar el canal no demuestra funcionamiento del sensor. Probar: crear PIN, cerrar/abrir, desbloquear con PIN, huella correcta/incorrecta, cancelar, enviar al fondo, volver, girar y guardar/editar/borrar registros. En Android moderno comprobar local_auth y en un equipo sin huellas verificar que el PIN siempre funcione.

## Validación y APK

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --flavor trial
```

Salida esperada de compilación: `build/app/outputs/flutter-apk/app-trial-debug.apk`. Para instalar con un Android conectado: `flutter install --debug --flavor trial`. El generador de prueba está disponible únicamente en builds debug.

La validación inicial se realizó sin teléfono. Ahora hay un Huawei DUB-LX3 con Android 8.1/API 27 conectado para validar la variante trial. No hay emulador configurado. Los resultados efectivos de análisis, pruebas y compilación se registran al finalizar en `VALIDATION.md`. iOS y la biometría real necesitan validación en sus dispositivos.

## Dependencias

Riverpod: dependencias/estado; go_router: rutas; sqflite: SQLite; cryptography: PBKDF2; flutter_secure_storage: secretos; shared_preferences: preferencias; local_auth: biometría moderna; device_info_plus: API Android; intl: fechas es_MX; path/path_provider: rutas locales; package_info_plus: versión. sqflite_common_ffi se utiliza solo en pruebas.

## Evolución futura

Las estadísticas son descriptivas y **no constituyen diagnóstico médico ni psicológico**. La Etapa 2 ya incorpora análisis por actividad, tendencias, sueño/pasos manuales y reportes PDF. Health Connect nativo está integrado en dispositivos compatibles; respaldo cifrado y sincronización quedan fuera de alcance.


## Variante de prueba en Huawei

Se añadieron dos sabores Android. `production` conserva `com.example.moodwave`. `trial` usa **com.example.moodwave.trial** y aparece como **MoodWave Prueba**. Cada una tiene sus propios datos, PIN y preferencias; la variante de prueba puede convivir con la app Kotlin instalada.

```powershell
flutter run --flavor trial -d 5XJRX19509005779
flutter build apk --debug --flavor trial --split-per-abi --target-platform android-arm64
```

El APK ARM64 para el Huawei está en `build/app/outputs/flutter-apk/app-trial-debug.apk`. Para producir el identificador original usa `--flavor production`; no lo instales sobre la app Kotlin sin preparar antes sus datos. VS Code inicia por defecto la configuración MoodWave Prueba. Al existir sabores Android, los comandos de ejecución y compilación necesitan indicar `--flavor`.


### Prueba física de huella

El usuario confirmó el desbloqueo biométrico en el Huawei DUB-LX3 con Android 8.1/API 27 usando MoodWave Prueba. En ese sistema la aplicación utiliza el fallback nativo FingerprintManager. Los escenarios de cancelación/error y la biometría moderna en otros dispositivos todavía requieren sus propias pruebas.

## Experiencia de registro renovada

Hoy se organiza como un recorrido de tres momentos: **Sentir**, **Vivir** y **Recordar**. El selector emocional cambia de distribución según el ancho y el tamaño de letra; las selecciones tienen animación breve y respuesta háptica. La energía se representa como una batería visual y las actividades tienen iconos. La reflexión es opcional y ofrece ideas que nunca sustituyen el texto ya escrito.

Después de guardar se muestra una tarjeta personal del día y la semana en colores; se puede volver a editar. Los pasos conservan sus selecciones y el botón principal permanece en su propia zona, fuera del contenido desplazable. Se renovaron además los encabezados con ondas, la navegación, el perfil y las tarjetas de datos. No se modificó el esquema SQLite ni el contrato biométrico.

El diseño respeta la preferencia del sistema para reducir animaciones. No incorpora vídeos, fuentes descargadas, bibliotecas de animación ni nuevos paquetes. Las capturas de prueba en `docs/screenshots/journey-*.png` muestran datos ficticios; los emojis pueden variar en el Huawei.

### Trabajo con poco espacio

Para cambios de interfaz, primero ejecutar `flutter analyze` y las pruebas; compilar solamente cuando se necesite una actualización en el teléfono. Generar únicamente `trial` para ARM64 en el Huawei. Conservar una sola copia del APK más reciente en `artifacts/apk/moodwave-trial-debug.apk`, después usar `flutter clean` y `flutter pub get --offline` para recuperar espacio y restaurar la configuración de edición. No eliminar cachés compartidas ni herramientas Android de otros proyectos.


## Etapa 2 disponible

Se conserva la Etapa 1. Patrones incluye Resumen, Actividades, Tendencias, Sueño y pasos, Predicción y Reportes. SQLite v4 migra sin borrar registros. Salud manual siempre disponible; Health Connect en API28+ mediante permisos explícitos. Consulta `docs/STAGE2_IMPLEMENTATION.md` para arquitectura, archivos, fórmulas, modelo, privacidad, límites de memoria y prueba en Huawei. `docs/STAGE2.md` corresponde a la entrega previa.

## Datos de demostración sintéticos

En compilaciones de desarrollo, `Perfil → Configuración → Herramientas de demostración` permite generar un escenario reproducible de 120 días con la semilla `20261031`. Incluye tendencia por cuatro periodos, actividades, sueño, pasos, ruido controlado y ausencias intencionales para probar gráficas, insights, predicción y reportes. Cada registro queda marcado con `isTest` y fuente `synthetic`; la acción **Eliminar datos sintéticos** solo borra esos registros y nunca los reales. El escenario no representa evidencia clínica y sus relaciones son descriptivas, no causales.
