import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screen/home_screen.dart';
import 'providers/word_provider.dart';

void main() {
  runApp(const WordApp());
}

class WordApp extends StatelessWidget {
  const WordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WordProvider>(
      create: (context) => WordProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '오늘의 영단어 UP!',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}