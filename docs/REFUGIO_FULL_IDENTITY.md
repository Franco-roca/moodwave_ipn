# Refugio natural: identidad completa

Rama: `design/refugio-natural`. Punto previo: `refugio-before-full-identity`.

## Abrir

```powershell
flutter run --flavor trial -t lib/main.dart -d emulator-5554
```

Usa el PIN habitual. El nombre Android sigue siendo MoodWave Prueba. No se
crean registros ni se cambian permisos para enseñar el diseño.

## Cobertura

- Hoy y semana: rostros de acuarela; ilustración central día/noche.
- Calendario: rostros en cada celda con registro, leyenda y detalle seleccionado.
- Análisis: avatares ilustrados en las seis pestañas y escenas diferentes para
  Resumen, Actividades, Tendencias, Sueño y pasos, Predicción y Reportes.
- Perfil: mochila/avatar, métricas, actividad frecuente y configuración.
- Reportes, Configuración, privacidad, salud, PIN, apoyo y controles secundarios:
  iconos compartidos y estilos del tema.
- Cabeceras con nueve escenas en dos atlas (día y noche); noches con luna,
  ventanas cálidas y faroles. Ilustraciones decorativas sin acciones nuevas.
- Se mantienen los símbolos funcionales de retroceso, editar, cerrar, expandir
  y los indicadores direccionales de datos: su significado no se sustituye
  por una ilustración ambigua. Colores y tipos de gráficos siguen al tema.

No se modificaron dominio, datos, seguridad, cálculos ni secuencia de pantallas.
El campo de apodo conserva su comportamiento y su inicial cuando existe nombre.
Se preservan las etiquetas de acciones, estados y permisos de Health Connect.

## Icono de aplicación

Emoción feliz dorada en una cabaña. Recursos:

- `assets/refugio/app-icon-1024.png`: original exportado RGB sin alfa.
- `assets/refugio/app-icon-512.png`: exportación RGB para ficha de tienda.
- `assets/refugio/app-icon-foreground-1024.png`: primer plano transparente.
- Android: launcher 48/72/96/144/192 px; primer plano adaptativo
  108/162/216/324/432 px, fondo independiente y silueta monocroma Android 13+.
- iOS: se exportaron los tamaños declarados en Contents.json, incluido 1024px,
  sin canal alfa. Compilación iOS no realizada en Windows.

Exportación reproducible: `tool/export_refugio_icons.ps1`, con System.Drawing
solo para redimensionado y composición técnica de las capas. No cambia ninguna
política permanente de ejecución. El arte se creó con image_gen integrado.
Se preservaron los originales; los recursos referenciados se copiaron al proyecto.
Los originales de iconos y la documentación no se incluyen en el bundle Flutter.

Referencias técnicas oficiales:
https://developer.android.com/develop/ui/compose/system/icon_design_adaptive
https://developer.android.com/distribute/google-play/resources/icon-design-specifications

## Rendimiento y accesibilidad

Dos atlas de banners y un atlas de símbolos compartidos; decodificación única,
resolución limitada, sin ampliar bitmaps ni pedir imágenes por red. Caché síncrona
para imágenes ya listas al cambiar de pestaña. Las ilustraciones decorativas
se excluyen de la lectura; las etiquetas y estados de los controles permanecen.
Los rostros mantienen su nombre/valor accesible en los registros. Los banners
usan una capa verde opaca bajo el texto para separar ilustración y lectura.
No se añadieron animaciones permanentes. La selección de tema existente decide
qué ilustraciones se usan, también al seguir el modo del sistema.

## Evidencias

- Suite general ejecutada tras las sustituciones: 99 aprobadas; conserva el fallo
  previo de PDF (17 muestras esperadas, 23 obtenidas).
- Cinco pruebas nuevas de identidad: Calendario/Perfil/Reportes, seis pestañas
  de Análisis, intercambio de cabaña al cambiar brillo y anchos 320 con texto 1.4.
- Capturas en `docs/screenshots/refugio-full/`, con datos sintéticos en memoria.
- Formatos PNG comprobados leyendo IHDR: RGB opaco en iconos de tienda/iOS y
  RGBA en primeros planos adaptativos. Tamaños de todas las densidades verificados.
- iOS, TalkBack manual completo y comportamiento de máscaras en launchers de
  fabricantes siguen pendientes; la compilación Android sí se verifica.

## Resultado final

La suite completa finalizó con 103 pruebas aprobadas y el mismo fallo previo de
PDF. Las cinco pruebas específicas finales de identidad pasaron, incluida una
comparación de píxeles para verificar que los atlas diurno y nocturno son distintos.
El análisis no añade incidencias: quedan los tres avisos de llaves previos.
La compilación Android y la instalación del APK final finalizaron correctamente;
Android confirmó arranque con `Status: ok`. Se conserva la autenticación existente.

Las últimas 11 pruebas focalizadas (identidad, recorrido y Etapa 2 visual) también pasaron después del ajuste de banners. Hay 20 capturas nuevas con datos ficticios.
