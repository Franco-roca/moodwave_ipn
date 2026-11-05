# Refugio natural

Implementaci?n en rama `design/refugio-natural`. Restauraci?n previa:
`d33508d` en la rama `design-lab`.

## Abrir en Android

Elegir **MoodWave Refugio natural (Android)** en VS Code y pulsar F5, o:

```powershell
flutter run --flavor trial -t lib/main.dart -d emulator-5554
```

Es la aplicaci?n completa, con su PIN y sus datos habituales de la variante trial.
El laboratorio anterior sigue disponible mediante su configuraci?n independiente.

## Cambios visuales

- Paleta bosque, crema y albaricoque; oscuro con superficies verde profundo.
- Encabezados bot?nicos, tipograf?a serif en t?tulos y Roboto local para lectura.
- Ilustraci?n de una caba?a y bosque, ocho rostros de acuarela en atlas local.
- Botones, navegaci?n, formularios y tarjetas con estilos compartidos.
- R?tulos y estados de selecci?n preservados; decoraciones excluidas de sem?ntica.
- Animaciones respetan la preferencia existente de reducir movimiento.

Los cambios est?n en presentaci?n y configuraci?n de recursos. No se modificaron
rutas, pasos, acciones, validadores, dominio, SQLite, preferencias, PIN, biometr?a,
Health Connect, reportes ni modelos. La disposici?n sigue siendo desplazable;
no se fuerza a encajar todo en una pantalla ni se reduce la escala de texto.

## Recursos e instrucciones de generaci?n

Recursos creados con la herramienta integrada imagegen, no con CLI. Se preservan
los originales; las copias usadas por la app son:

- `assets/refugio/sanctuary.png`: ilustraci?n con transparencia.
- `assets/refugio/emotions.png`: atlas transparente 4x2, orden del enum Mood.

Direcci?n del prompt del refugio: production mobile UI illustration asset only,
original peaceful woodland clearing, warm timber cabin, stepping stone path,
large curved tree, olive leaves, sage forest hills, apricot sun, hand-painted
gouache and paper-cut depth; forest #285747, sage #82936B, apricot #F3B58D,
honey and ivory; circular medallion, transparent outside, no text or mockup.

Direcci?n del prompt de emociones: strict uniform 4 columns by 2 rows transparent
sprite atlas; centered separate gouache pebble faces with padding; angry terracotta,
sad blue-gray with tear, discouraged lavender, worried sage with ink scribble,
neutral oatmeal, good apricot, happy honey, excellent coral with sparkles; adult
cozy watercolor, dark expressive ink features, no text, labels or frames.

El atlas se decodifica una sola vez con resoluci?n limitada y se dibuja por
rect?ngulos; no hay descargas de im?genes ni bucle de animaci?n. Las hojas de
encabezados y semana son dibujo nativo de Flutter. El estilo serif usa la fuente
del sistema, por lo que su forma exacta puede variar entre Windows y Android.

## Validaci?n

- An?lisis global: sin errores nuevos; tres avisos existentes de llaves en
  screens.dart y synthetic_data_generator.dart.
- Suite existente ejecutada: 98 pruebas aprobadas y un fallo preexistente de PDF
  (espera 17 muestras, recibe 23). No se cambi? esa prueba ni su dominio.
- Nueva prueba visual: cuatro combinaciones de ancho 320/412, claro/oscuro;
  ancho 320 con escala 2x, navegaci?n por Sentir/Vivir/Recordar sin desbordamientos.
- Capturas: `docs/screenshots/refugio/`.
- Contraste de las parejas de colores principales se comprueba por separado;
  revisi?n manual completa con TalkBack y pruebas de teclado siguen pendientes.

La ilustraci?n conserva la direcci?n aprobada; la implementaci?n nativa adapta
medidas y contenido real a cada dispositivo. No es una captura de la maqueta.

## Evidencia final

An?lisis espec?fico: sin incidencias. Pruebas finales de journey, widgets y
Refugio visual: 11 aprobadas. Contrastes calculados con luminancia relativa:
texto/crema 10.68:1, bot?n claro 8.25:1, paso activo 6.53:1, texto oscuro
13.23:1, bot?n oscuro 8.26:1 y cabecera 6.57:1. Son parejas principales,
no una certificaci?n de accesibilidad de toda la aplicaci?n.
