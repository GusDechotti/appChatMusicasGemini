import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerador de letras de músicas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.deepPurple[50],
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: PostRequestPage(),
    );
  }
}

class PostRequestPage extends StatefulWidget {
  @override
  _PostRequestPageState createState() => _PostRequestPageState();
}

class _PostRequestPageState extends State<PostRequestPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  String _responseMessage = "";
  stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isTextVisible = false;

  Future<void> sendTextToAPI(String text, {String? userVisibleMessage}) async {
    setState(() {
      _chatHistory.add({
        "sender": "user",
        "message": userVisibleMessage ?? text,
      });
      _controller.clear();
    });

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyD7lHhBS9OWywVqM-xkqWRzCA4ePeAJT3Y');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "contents": [
          {
            "parts": [
              {"text": text}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.9,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 800
        }
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          var candidate = data['candidates'][0];
          var parts = candidate['content']['parts'];
          if (parts.isNotEmpty) {
            var text = parts[0]['text'];
            setState(() {
              _chatHistory.add({"sender": "bot", "message": text});
            });
          }
        }
      } catch (e) {
        setState(() {
          _responseMessage = 'Erro ao processar a resposta da API.';
        });
      }
    } else {
      setState(() {
        _responseMessage =
            'Erro ao enviar o texto. Código: ${response.statusCode}';
      });
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      });
    }
  }

  void _stopListening() async {
    setState(() {
      _isListening = false;
    });
    await _speech.stop();
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.speak(text);
  }

  void _clearChat() {
    setState(() {
      _chatHistory.clear();
      _responseMessage = '';
    });
  }

  @override
  void dispose() {
    super.dispose();
    _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gerador de letras de músicas'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            tooltip: 'Limpar conversa',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final chat = _chatHistory[index];
                  final isUser = chat['sender'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.purpleAccent[100]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat['message'] ?? '',
                            style: TextStyle(fontSize: 16),
                          ),
                          if (!isUser)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  _speakText(chat['message'] ?? '');
                                },
                                icon: Icon(Icons.music_note, size: 18),
                                label: Text('Cantar'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size(60, 30),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    sendTextToAPI(
                      "gere apenas uma letra de uma música curta",
                      userVisibleMessage: "Música aleatória",
                    );
                  },
                  child: Text('Música aleatória'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isTextVisible = !_isTextVisible;
                    });
                  },
                  child: Text(_isTextVisible
                      ? 'Ocultar Texto'
                      : 'Música personalizada'),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_isTextVisible)
              Column(
                children: [
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Digite sua palavra ou frase para a música',
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            String text = _controller.text;
                            if (text.isNotEmpty) {
                              sendTextToAPI(
                                "gere apenas uma letra de uma música curta que contenha o seguinte => $text",
                                userVisibleMessage: text,
                              );
                            } else {
                              setState(() {
                                _responseMessage =
                                    'Por favor, digite ou fale algum texto.';
                              });
                            }
                          },
                          child: Text('Enviar'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                            _isListening ? Icons.mic_off : Icons.mic),
                        onPressed:
                            _isListening ? _stopListening : _startListening,
                      ),
                    ],
                  ),
                ],
              ),
            SizedBox(height: 10),
            if (_responseMessage.isNotEmpty)
              Text(
                _responseMessage,
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
