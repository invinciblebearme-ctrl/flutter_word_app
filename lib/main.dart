import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/word_provider.dart';
import 'screen/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WordProvider()),
      ],
      child: const WordApp(),
    ),
  );
}

class WordApp extends StatelessWidget {
  const WordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '오늘의 영단어 UP!',
      theme: ThemeData.dark(useMaterial3: true),
      home: const SplashScreen(), // ✅ 시작 화면을 Splash로 지정
    );
  }
}