> Historial de la entrega anterior. La versión vigente se documenta en [STAGE2_IMPLEMENTATION.md](STAGE2_IMPLEMENTATION.md).

# Etapa 2 — inspección y decisiones

Base inspeccionada: Flutter 3.47.7/Dart 3.13.5; SQLite v2 en RecordRepository; AppStore inyectado por Riverpod; go_router con cuatro pestañas y rutas secundarias; recorrido Sentir/Vivir/Recordar; servicios de PIN y biometría; canal FingerprintManager API 23–27; Android minSdk 24 y variantes production/trial. La huella en Huawei API 27 fue confirmada por el usuario en la Etapa 1. No hay .git en esta carpeta.

Se conserva la estructura y la seguridad. Se añadirá SQLite v3 con tabla daily_health_data independiente, guardado conjunto transaccional y servicios de análisis puros. Patrones ocupa la tercera pestaña y tendrá cinco secciones secundarias. Health Connect queda como fuente no disponible, sin paquetes ni permisos adicionales. Gráficas vectoriales propias, sin fl_chart. PDF generado bajo demanda en un isolate, vista previa de una página por vez a baja resolución y sin fuentes de red. Solo se conservará un APK trial ARM64 al finalizar y se limpiarán temporales.

## Implementación final

La Etapa 1 se conserva. Las cuatro pestañas son Hoy, Calendario, Patrones y Perfil. Patrones tiene Resumen, Actividades, Tendencias, Sueño y pasos, y Reportes. Los filtros, métricas y desplazamientos se conservan al cambiar de sección; solo se construye la sección activa.

### Archivos nuevos

- `lib/features/analytics/domain/analytics.dart`: DateSpan, modelos y EmotionalSummaryService, ActivityAnalyticsService, TrendAnalysisService, PatternDetectionService y HealthAnalyticsService.
- `lib/features/analytics/presentation/providers/analytics_provider.dart`: composición e inyección de servicios y snapshot del periodo.
- `lib/features/analytics/presentation/screens/patterns_screen.dart`: las cinco secciones y explicaciones bajo demanda.
- `lib/features/analytics/presentation/widgets/charts.dart`: barras tocables y tendencia vectorial con puntos, huecos, media y detalle textual.
- `lib/features/health/domain/daily_health.dart`: entidad, fuentes, validación y contrato HealthDataSource.
- `lib/features/health/data/health_repository.dart`: SQLite, rango, upsert, borrado y stream de cambios.
- `lib/features/health/presentation/health_fields.dart`: captura manual opcional.
- `lib/features/health/presentation/providers/health_provider.dart`: mensaje de disponibilidad según API.
- `lib/features/reports/domain/report_data.dart`: MoodWaveReportData y ReportDataService.
- `lib/features/reports/domain/pdf_report_service.dart`: PdfReportService, texto seguro para PDF y generación vectorial.
- `lib/features/reports/data/report_platform.dart`: generación en isolate, raster de una sola página, guardado y menú para compartir; sustituible en pruebas.
- `lib/features/reports/presentation/report_screen.dart`: selección semanal/mensual, privacidad, vista previa, guardar y compartir.
- `test/analytics_test.dart`, `test/health_repository_test.dart`, `test/report_test.dart`, `test/stage2_widgets_test.dart`.
- `assets/fonts/`: Roboto regular y negrita (~335 KiB en total) con licencia; solo para PDF. Copiadas del SDK local, sin fuentes de red.

### Archivos modificados

`lib/app/app.dart`, `lib/app/state.dart`, `lib/app/screens.dart`, repositorio emocional, editor y tarjeta del día; `pubspec.yaml`/`pubspec.lock`; `test/journey_test.dart` para aceptar los campos opcionales; MainActivity Kotlin para el selector de archivo PDF, configuración Gradle y documentación. El manifiesto principal mantiene los permisos biométricos y minSdk 24; el manifiesto combinado añade el FileProvider de printing para compartir archivos.

### Dependencias

Se resolvieron `pdf 3.13.1`, `printing 5.15.1` y `flutter_localizations` incluido en el SDK. Se verificó localmente que printing declara minSdk 21. Se mantienen compileSdk/targetSdk 36 y minSdk 24. El subproyecto printing se compila contra el SDK 36 ya instalado para evitar descargar SDK 34. No se añadieron fl_chart, Health Connect ni share_plus: las gráficas se dibujan directamente y printing ya proporciona compartir mediante el menú del sistema.

### SQLite v3

Migración v2→v3: CREATE TABLE daily_health_data, sin alterar ni borrar registros emocionales. Las migraciones v1→v2 siguen presentes. Campos: id, dateKey único, fecha, sleepMinutes nullable (0–1440), steps nullable (0–200000), source (manual/health_connect/imported), updatedAt e isTest. La fuente y los timestamps se conservan en el repositorio. Hay pruebas de migración con registros previos.

El guardado desde Hoy utiliza una única transacción para emoción y salud. Si falla la salud, se revierte también la emoción. Una captura vacía no bloquea el registro emocional; al vaciar datos físicos existentes se elimina esa fila. El borrado de un día elimina su emoción y sus datos físicos. El borrado total requiere doble confirmación y conserva PIN/preferencias. Los PDF exportados no se eliminan automáticamente. El generador debug usa semilla controlada, 90 días, huecos intencionados y marcas de prueba; no sobrescribe emoción ni salud reales.

### Fórmulas y límites de interpretación

- Media general = suma de valores / registros del periodo.
- Media por actividad = suma de valores de días con esa actividad / cantidad de esos días. Se normalizan espacios y mayúsculas y se cuenta una actividad una sola vez por fecha.
- Diferencia = media de actividad − media general del mismo periodo, en puntos, con un decimal.
- Presencia = días con actividad / registros del periodo ×100. Este porcentaje solo describe frecuencia; las tendencias no se expresan en porcentajes.
- Evidencia: 1–2 observaciones insuficientes, 3–4 relación inicial y ≥5 mayor respaldo en los datos personales. Máximo tres patrones de actividades, con al menos tres observaciones y diferencia absoluta ≥0.25. Orden: mayor muestra y luego mayor diferencia absoluta.
- Tendencia: últimos 7/30 días contra sus 7/30 anteriores al cierre de la referencia seleccionada. Se exigen tres registros en ambos. Ascendente ≥+0.25, descendente ≤−0.25, estable entre ambos.
- Sueño: <360, 360–419, 420–540 y >540 minutos. Pasos: <2000, 2000–4999, 5000–7999 y ≥8000. Cruce por dateKey local. Campos ausentes se excluyen; cero es válido. Medias físicas y patrones se calculan sobre días emparejados con emoción y siempre muestran su cantidad. Máximo dos patrones físicos, al menos tres observaciones en el grupo; comparación contra la media de días emparejados con ese mismo dato.
- Ninguna conclusión demuestra causalidad ni constituye un diagnóstico. Cada patrón explica sus medias, diferencia y tamaño de muestra.

### Uso

En **Hoy → Vivir → Bienestar físico**, agregar horas/minutos y/o pasos. Ambos son opcionales. Se muestran nuevamente en la tarjeta guardada. En **Patrones** elegir semana, mes o últimos 7/30/90 días y fecha de referencia. En Actividades alternar ánimo/energía y tocar una barra; en Tendencias tocar un día o abrir Fechas y valores. Los huecos no se convierten en cero ni se conectan por líneas.

Health Connect no está implementado ni solicita permisos. La interfaz futura permanece y API 27 muestra que se pueden registrar datos manualmente. Los valores manual/imported/health_connect se prueban como fuentes de almacenamiento; esto no implica que exista importador externo.

### PDF y privacidad

En **Patrones → Reportes → Generar reporte**, elegir semana/mes y una fecha de ese periodo. Reflexiones desactivadas por defecto; activarlas exige aceptar un diálogo. Sueño/pasos se incluyen si hay datos y el usuario mantiene la opción activa. El modelo enviado al generador elimina de antemano las reflexiones cuando no se autorizan.

La generación se ejecuta en un isolate y conserva un único PDF en la pantalla. La vista previa carga una sola página a 72 dpi y libera la imagen anterior; el archivo guardado sigue siendo vectorial. Los emojis emocionales se representan mediante nombre y color. Otros símbolos sin representación se sustituyen por [símbolo], según la nota de la sección de reflexiones. Se usan fuentes embebidas para español y acentos. El PDF no lee PIN, hash, salt ni datos biométricos.

Android guarda mediante ACTION_CREATE_DOCUMENT y permite elegir ubicación sin permiso de almacenamiento global (compatible API 27). Compartir abre el menú del sistema mediante printing. En plataformas distintas de Android el guardado usa documentos de la aplicación; la validación física de iOS queda pendiente. Salir hacia el selector o una app externa puede activar el bloqueo de privacidad al regresar. Los reportes ya exportados quedan bajo control del usuario; borrar SQLite no los elimina.

### Memoria y espacio

Sin vídeos, IA remota, Health Connect ni biblioteca adicional para gráficas. Periodos de hasta 90 puntos; una sección y una página PDF visibles a la vez. Fuentes locales pequeñas y PDF de muestra de aproximadamente 25 KiB. Gradle: heap máximo 2 GiB, metaspace 768 MiB, dos trabajadores, sin paralelismo ni daemon persistente; Kotlin daemon limitado a 512 MiB. Estos son límites de compilación, no una medición de RAM total del teléfono. El perfil de consumo real en Huawei todavía debe medirse.

Solo se genera trial/ARM64. Se conserva un APK en `artifacts/apk/moodwave-trial-debug.apk`; después de compilar/instalar se limpian build y .dart_tool y se restaura configuración con pub get offline. No se eliminan SDK ni cachés compartidas.

### Validación

Flutter doctor sin problemas. `flutter analyze`: sin incidencias. `flutter test`: 63 aprobadas, incluidas las de Etapa 1, migración, rollback transaccional, fuentes de salud, análisis, PDF con/sin datos y pantallas pequeñas/tema oscuro. PDF final de muestra: `output/pdf/moodwave-demo.pdf`, tres páginas revisadas con Poppler, sin cuadros ni texto cortado. Datos ficticios; no son datos del teléfono. El resultado de compilación e instalación se registra en VALIDATION.md.

### Límites y prueba física pendiente

Sin Health Connect, rango personalizado ni importador externo. Sin cifrado adicional de SQLite, respaldo cifrado, nube o sincronización. La huella API 27 fue confirmada manualmente en Etapa 1; las rutas de PIN/biometría se conservan, pero conviene repetir la prueba tras la actualización. En Huawei comprobar: conservar registros después de migrar, guardar sueño/pasos vacíos y válidos, errores de validación, calendario, cambio de secciones, generar PDF con/sin salud y reflexiones, navegar páginas, cancelar/guardar en Archivos, compartir con la app elegida y volver a desbloquear. Validar el pico de RAM y fluidez en ese dispositivo antes de afirmar rendimiento medido.

### Cierre de compilación e instalación

APK trial ARM64 generado e instalado correctamente en Huawei API 27. AAPT confirmó minSdk 24 y targetSdk 36. El usuario confirmó que desbloquea, ve Patrones y conserva sus registros anteriores. Se mantiene la app Kotlin separada. El APK actualizado se conserva en `artifacts/apk/moodwave-trial-debug.apk` (104.98 MiB) y el PDF ficticio revisado en `output/pdf/moodwave-demo.pdf` (25,690 bytes, tres páginas). Después de la limpieza quedan aproximadamente 23.97 GiB libres. El detalle de resultados y las pruebas físicas pendientes están en VALIDATION.md.

Fuentes de los paquetes PDF: https://pub.dev/packages/pdf y https://pub.dev/packages/printing; se inspeccionaron también sus fuentes y configuración Android descargadas mediante flutter pub.

Si ya existían registros debug de Etapa 1, el generador no los sobrescribe ni añade datos físicos sobre ellos. Para crear una muestra completa de Etapa 2, usar primero Eliminar registros de prueba (con confirmación) y después Generar 90 días de prueba. Los registros reales se conservan.
