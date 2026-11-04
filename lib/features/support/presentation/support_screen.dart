import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/support_resources.dart';

Future<void> showSupport(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SupportScreen(),
      ),
    );

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Un momento para ti')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.favorite_outline,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'No tienes que atravesar esto a solas',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Si lo que escribiste refleja cómo te sientes ahora, considera contactar a alguien de confianza y pedir compañía. También puedes hablar con un profesional de salud mental. Mereces ser escuchado sin juicios.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Si crees que podrías hacerte daño de inmediato, busca ayuda presencial urgente o acude al servicio de urgencias más cercano.',
          ),
          for (final r in supportResources)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.name} · ${r.country}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text('Gratuita y confidencial · 24 horas'),
                    SelectableText(
                      r.phone,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: r.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Número copiado')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar teléfono'),
                    ),
                    SelectableText(r.website),
                  ],
                ),
              ),
            ),
          const Text(
            'Este aviso es una medida preventiva basada en expresiones directas, no una evaluación clínica. Puede equivocarse. El texto no se envía ni se guarda una etiqueta de riesgo.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver a mi registro'),
          ),
        ],
      ),
    ),
  );
}
