import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GreenBotService {
  late final GenerativeModel _model;
  late ChatSession _chat;

  GreenBotService() {
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction: Content.system(_systemPrompt()),
    );
    _chat = _model.startChat();
  }

  String _systemPrompt() {
    return """
    Eres GreenBot, asistente agrícola inteligente de GreenCode.
    Respondes ÚNICAMENTE sobre temas agrícolas, suelos, clima y cultivos.
    Si te preguntan algo fuera de ese tema, rediriges amablemente.
    Responde siempre en español, de forma breve y práctica. Máximo 3 párrafos.

    === DATOS ACTUALES DE LA PARCELA ===
    Ubicación     : 19.0414, -98.2063 — Puebla, México
    Índice UV     : 6.5 → Moderado
    pH del suelo  : 6.8 → Óptimo
    Temperatura   : 21°C → Templado
    Humedad suelo : 72% → Alta

    === CULTIVOS (1023 ha totales) ===
    Maíz     : 31.3% — 320.5 ha
    Aguacate : 23.5% — 240.7 ha
    Frijol   : 17.6% — 180.2 ha
    Caña     : 9.3%  — 95.3 ha
    Café     : 11.8% — 120.4 ha
    Tomate   : 6.4%  — 65.9 ha
    """;
  }

Future<String> enviarMensaje(String mensaje) async {
  try {
    final response = await _chat.sendMessage(Content.text(mensaje));
    return response.text ?? 'No pude generar una respuesta.';
  } catch (e, stack) {
    print('❌ ERROR GREENBOT: $e');
    print('Stack: $stack');
    return 'Error al conectar con GreenBot. Intenta de nuevo.';
  }
}

  void reiniciarChat() {
    _chat = _model.startChat();
  }
}