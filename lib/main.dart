
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'chat_screen.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
await dotenv.load(fileName: ".env");
runApp(const MyApp());
}

class MyApp extends StatelessWidget {
const MyApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
title: 'ChatGPT 음성 대화',
theme: ThemeData(
colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
useMaterial3: true,
),
home: const ChatScreen(),
debugShowCheckedModeBanner: false,
);
}
}
