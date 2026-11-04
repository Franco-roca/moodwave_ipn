package com.example.moodwave

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class HealthRationaleActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setContentView(TextView(this).apply {
            text = "MoodWave · Privacidad\n\nSueño y pasos son opcionales. Solo se leen al importar un rango que eliges. Se guardan localmente para comparar con tus emociones, sin servidores ni diagnósticos. Puedes revocar permisos en Health Connect o en Perfil > Configuración. Exportar o compartir crea una copia externa que controlas tú."
            textSize = 20f
            setPadding(32, 48, 32, 32)
        })
    }
}
