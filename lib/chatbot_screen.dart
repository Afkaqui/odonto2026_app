import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // Clave de Gemini: se inyecta al compilar (repo publico, no hardcodear).
  //   --dart-define=GEMINI_KEY=<tu-clave>
  final String _apiKey = const String.fromEnvironment('GEMINI_KEY', defaultValue: '');
  
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  
  // Usuarios
  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'Odontólogo');
  final ChatUser _geminiUser = ChatUser(
    id: '2', 
    firstName: 'Asistente IA', 
    profileImage: "https://upload.wikimedia.org/wikipedia/commons/8/8a/Google_Gemini_logo.png"
  );

  List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  void _initGemini() {
    _model = GenerativeModel(
      model: "gemini-2.5-flash", // El modelo que validaste que funciona
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "Eres un asistente experto en Odontopediatría y Psicología Infantil. "
        "Tu objetivo es dar recomendaciones breves y prácticas para manejar la ansiedad en niños durante la consulta dental. "
        "Sé directo, empático y profesional."
      ),
    );
    _chatSession = _model.startChat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asistente de Ansiedad"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      // SafeArea evita que el chat se solape con el notch o barra inferior
      body: SafeArea(
        child: DashChat(
          currentUser: _currentUser,
          typingUsers: _isTyping ? [_geminiUser] : [],
          onSend: _sendMessage,
          messages: _messages,
          inputOptions: InputOptions(
            inputDecoration: InputDecoration(
              hintText: "Describe la situación (ej: niño llorando)...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
          messageOptions: const MessageOptions(
            currentUserContainerColor: Colors.teal,
            containerColor: Colors.grey,
            textColor: Colors.white,
            showOtherUsersAvatar: true,
            showTime: true,
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage(ChatMessage chatMessage) async {
    setState(() {
      _messages.insert(0, chatMessage);
      _isTyping = true;
    });

    try {
      // Enviar mensaje a Gemini
      final response = await _chatSession.sendMessage(
        Content.text(chatMessage.text),
      );

      final text = response.text;
      if (text != null) {
        ChatMessage geminiMessage = ChatMessage(
          user: _geminiUser,
          createdAt: DateTime.now(),
          text: text,
        );

        setState(() {
          _messages.insert(0, geminiMessage);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: Verifique internet o API Key.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }
}