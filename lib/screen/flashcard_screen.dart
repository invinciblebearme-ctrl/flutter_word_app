import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FlashcardScreen extends StatefulWidget {
  final int round;

  const FlashcardScreen({super.key, required this.round});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<Word> wordList;
  int currentIndex = 0;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<WordProvider>(context, listen: false);
    wordList = provider.getWordsByRound(widget.round);
  }

  void _speakWord(String word) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(word);
  }

  void _nextCard() {
    setState(() {
      if (currentIndex < wordList.length - 1) {
        currentIndex++;
      }
    });
  }

  void _prevCard() {
    setState(() {
      if (currentIndex > 0) {
        currentIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (wordList.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("단어를 불러오는 중입니다...")),
      );
    }

    final word = wordList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${widget.round} - Flashcards'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _speakWord(word.name),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/${word.img}',
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        word.name,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        word.meaning,
                        style: const TextStyle(fontSize: 24, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _prevCard,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("이전"),
                ),
                ElevatedButton.icon(
                  onPressed: _nextCard,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("다음"),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}