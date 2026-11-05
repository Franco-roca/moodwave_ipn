# MoodWave · laboratorio de diseño

Primera iteración: tres composiciones de Hoy. Rama `design-lab`; punto de
restauración `design-lab-baseline-20261104`. La entrada de producción no cambia.

## Abrir

Seleccionar **MoodWave Laboratorio A/B/C** en Ejecutar y depurar de VS Code,
elegir un emulador Android y pulsar F5. Alternativamente:

```powershell
flutter devices
flutter run --flavor trial -t lib/design_lab/main.dart -d emulator-5554
```

El identificador debe coincidir con el dispositivo conectado. La instalación usa
el paquete trial existente: reemplaza su ejecutable, conserva sus datos y no los
abre desde el laboratorio. Para volver a la aplicación habitual:

```powershell
flutter run --flavor trial -t lib/main.dart -d emulator-5554
```

## Comparación

- A / Marea: registro guiado por Sentir, Vivir y Recordar.
- B / Cuaderno: página continua, jerarquía serif del sistema y separadores.
- C / Pulso: emoción y energía inmediatas; detalles opcionales desplegables.

El selector conserva el borrador. El botón superior de ajustes permite alternar
tema, ampliar texto, combinar paletas y simular estados. Vacío limpia únicamente
el borrador ficticio. Guardando y Error son escenarios manuales; el guardado
normal simula una espera de 500 ms y conserva el resultado en memoria.

Los modelos emocionales y validadores de sueño y pasos provienen del dominio
existente. No se inicializan AppStore, SQLite, preferencias, PIN ni Health Connect.
No hay dependencias nuevas. Tokens de tema, formas y dimensiones viven en
`lib/design_lab/tokens.dart`; el borrador está separado de la presentación.

## Alcance y decisiones

Esta iteración compara el registro, no implementa Calendario, Análisis, Perfil,
actividades personalizadas ni navegación entre esos destinos. La aplicación
habitual conserva esas funciones. Los iconos de emoción incluyen etiquetas y
selección explícita; no dependen de la representación de emojis del dispositivo.
Cuaderno usa la serif del sistema: puede variar entre Windows y Android.
Las paletas oscuras se derivan de ColorScheme; requieren revisión humana antes
de promoción a producción.

Priorizar en la evaluación: registrar sin detalles, completar todos los campos,
corregir errores y cambiar de variante sin perder el borrador. Después elegir
composición y tokens antes de extender a otras pantallas.

## Evidencias

```powershell
flutter analyze
flutter test --concurrency=1
flutter test test/design_lab_test.dart --dart-define=CAPTURE_LAB=true
flutter build apk --debug --flavor trial -t lib/design_lab/main.dart --target-platform android-x64
```

Capturas: `docs/screenshots/design-lab/variant-0.png` a `variant-2.png`.
Las capturas cargan Roboto local, Material Icons de la caché Flutter y, en Windows,
Georgia del sistema para la serif. No se redistribuyen fuentes del sistema.

Validación del 4 de noviembre de 2026:

- Compilación Android x86_64 e inicio en emulator-5554 realizados.
- Pruebas del laboratorio: validación, conservación del borrador, guardado y
  anchos 320/360/412 con texto 1x/2x. Se corrigió un desbordamiento en energía.
  Resultado final: 9 pruebas aprobadas; análisis específico sin incidencias.
- Suite completa: 98 aprobadas, 1 fallo en la prueba preexistente de PDF
  `Predicción requiere opt-in y agrega evaluación real al PDF`: espera 17
  muestras y obtiene 23. No se modificó el dominio ni esa prueba.
- Análisis global: tres avisos preexistentes sobre llaves en screens.dart y
  synthetic_data_generator.dart; sin errores nuevos del laboratorio.
- Pendientes: TalkBack manual, contraste medido, teclado en dispositivo,
  navegación completa y pruebas visuales de todos los escenarios en oscuro.

Referencias consultadas en la propuesta: documentación de estadísticas de Daylio
y texto/paleta de una propuesta de Dribbble. No se verificaron visualmente
Behance ni Material Design; sus accesos fueron bloqueados o requerían JavaScript.

## Traslado a C:\ROCA\moodwave_ipn

El 4 de noviembre de 2026 se verificó la rama design-lab y sus cambios después
del traslado. Las carpetas generadas conservaban el atributo ReadOnly: impedía
flutter clean y Gradle no podía borrar trialDebug. Se retiró ese atributo solo
en build, .dart_tool e ios/Flutter/ephemeral. Después flutter clean y flutter
pub get finalizaron correctamente. El análisis del laboratorio y sus 9 pruebas
pasaron desde la nueva ruta. No se modificaron dependencias ni datos de usuario.
La recompilación posterior al traslado generó correctamente el APK Android
(assembleTrialDebug, 77.9 s). El arranque no pudo confirmarse: el emulador
agotó la espera de am force-stop y no completó instalación/reinicio por ADB.
Requiere reiniciar el dispositivo virtual desde Device Manager y repetir el
comando de ejecución. No se borraron datos del emulador.
