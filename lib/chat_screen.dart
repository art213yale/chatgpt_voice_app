// lib/chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isLoading = false;
  String _lastWords = '';

  List<Map<String, String>> _messages = [];





  @override
  void initState() {
    super.initState();

    // 약간의 지연 후 초기화
    Timer(const Duration(milliseconds: 1500), () {
      _initSpeech();
      _initTts();

      // 앱 시작 시 "오늘 잘지냈어?" 메시지 보내기
      Timer(const Duration(milliseconds: 1000), () {
        _addBotMessage("오늘 잘지냈어?");
        _speakMessage("오늘 잘지냈어?");
      });
    });
  }








  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

// 음성 인식 초기화
  Future<void> _initSpeech() async {
    debugPrint("음성 인식 초기화 시작");


    try {
      final result = await _speechToText.initialize(
        onStatus: (status) => debugPrint("음성 인식 상태야: $status"),
        onError: (error) => debugPrint("음성 인식 오류야: $error"),
      );
      debugPrint("음성 인식 초기화 결과: $result");

      if (result) {
        // 사용 가능한 로케일 확인
        final locales = await _speechToText.locales();
        //debugPrint("사용 가능한 언어: ${locales.map((e) => e.localeId).toList()}");

        // 한국어 로케일 확인
        final koLocale = locales.where((locale) =>
        locale.localeId.contains("ko") ||
            locale.name.contains("Korean")).toList();

        if (koLocale.isNotEmpty) {
          debugPrint("한국어 로케일 발견: ${koLocale.first.localeId}");
        } else {
          debugPrint("한국어 로케일을 찾을 수 없습니다");
        }
      }

      setState(() {
        _speechEnabled = result;
      });
    } catch (e) {
      debugPrint("음성 인식 초기화 오류: $e");
      setState(() {
        _speechEnabled = false;
      });
    }
  }



// TTS 초기화
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVoice({"name": "Yuna", "locale": "ko-KR"});

    _flutterTts.setCompletionHandler(() {
      debugPrint("TTS 완료");
    });
  }

// 음성 인식 시작

  void _startListening() async {
    debugPrint("음성 인식 시작 oooooo");

    if (!_speechEnabled) {
      await _initSpeech();
      debugPrint("음성 인식 시작");
    }

    debugPrint("음성 인식 못함 oooooo");

    setState(() {
      _isListening = true;
      _lastWords = '';
    });

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: "ko_KR",
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }








// 음성 인식 중지
  void _stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    setState(() {
      _isListening = false;
    });

    if (_lastWords.isNotEmpty) {
      _sendMessage(_lastWords);
    }
  }

// 음성 인식 결과 처리
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

// 메시지 전송 (음성 또는 텍스트)
  void _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _messages.add({
        "role": "user",
        "content": message,
      });
      _textController.clear();
      _lastWords = '';
    });

    _scrollToBottom();

// ChatGPT API 호출
    try {
      final response = await _sendToChatGPT(message);
      _addBotMessage(response);
      _speakMessage(response);
    } catch (e) {
      _addBotMessage("죄송합니다. 오류가 발생했습니다: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// 봇 메시지 추가
  void _addBotMessage(String message) {
    setState(() {
      _messages.add({
        "role": "assistant",
        "content": message,
      });
    });
    _scrollToBottom();
  }

// TTS로 메시지 읽기
  Future<void> _speakMessage(String message) async {
    debugPrint("TTS 시작: $message");
    try {
      var result = await _flutterTts.speak(message);
      debugPrint("TTS 결과: $result");
    } catch (e) {
      debugPrint("TTS 오류: $e");
    }
  }

// 스크롤을 가장 아래로 이동
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _sendToChatGPT(String message) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null) {
      throw Exception("API 키가 설정되지 않았습니다.");
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // 이전 대화 내용을 포함한 메시지 형식 구성
    final List<Map<String, String>> formattedMessages = [];

    for (var msg in _messages) {
      formattedMessages.add({
        "role": msg["role"]!,
        "content": msg["content"]!,
      });
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': formattedMessages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        // UTF-8로 명시적 디코딩
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        final content = data['choices'][0]['message']['content'] as String;

        // 디버그 출력 - 원본 텍스트 확인
        debugPrint("API 응답 원본: $content");

        return content;
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint("API 호출 예외: $e");
      rethrow;
    }
  }












  @override
  Widget build(BuildContext context) {
    return Scaffold(



      appBar: AppBar(
        title: const Text('ChatGPT 음성 대화'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_voice),
            onPressed: () async {
              // 음성 인식 초기화 재시도
              await _initSpeech();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('음성 인식 초기화 ${_speechEnabled ? '성공' : '실패'}')),
              );
            },
          ),
        ],
      ),











      body: Column(
        children: [
// 채팅 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.deepPurple.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      message["content"]!,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              },
            ),
          ),

// 현재 인식 중인 텍스트 표시
          if (_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '인식 중: $_lastWords',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.deepPurple,
                ),
              ),
            ),

// 로딩 표시
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),

// 입력 부분
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
// 텍스트 입력창
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30.0)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    ),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _sendMessage(text);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8.0),

// 텍스트 전송 버튼
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      _sendMessage(_textController.text);
                    }
                  },
                ),

// 음성 인식 버튼
// 아래쪽 음성 인식 버튼
                IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  onPressed: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      if (!_speechEnabled) {
                        // 초기화되지 않았다면 초기화 시도
                        _initSpeech().then((_) {
                          if (_speechEnabled) {
                            _startListening();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('음성 인식을 초기화할 수 없습니다. 마이크 권한을 확인하세요.')),
                            );
                          }
                        });
                      } else {
                        _startListening();
                      }
                    }
                  },
                  color: _isListening ? Colors.red : Colors.deepPurple,
                ),



              ],
            ),
          ),
        ],
      ),
    );
  }
}

// pubspec.yaml 설정:
/*
name: chatgpt_voice_app
description: A voice chat app with ChatGPT integration

publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  speech_to_text: ^6.1.1
  flutter_tts: ^3.7.0
  http: ^1.1.0
  flutter_dotenv: ^5.1.0
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
  assets:
    - .env
*/

// macos/Runner/Info.plist에 추가할 내용:
/*
<key>NSMicrophoneUsageDescription</key>
<string>음성 인식을 위해 마이크 접근 권한이 필요합니다.</string>
*/

// macos/Runner/Configs/AppInfo.xcconfig에 추가할 내용:
/*
MACOSX_DEPLOYMENT_TARGET = 10.15
*/

// macos/Podfile에 추가할 내용:
/*
platform :osx, '10.15'
*/

// 프로젝트 루트에 .env 파일 생성하고 다음 내용 추가:
/*
OPENAI_API_KEY=your_api_key_here
*/