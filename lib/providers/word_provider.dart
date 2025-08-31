import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'; // 여기에 ChangeNotifier 있음
import '../models/word.dart';

class WordProvider extends ChangeNotifier {
  List<Word> _allWords = [];
  List<dynamic> indexList = [];

  /// 단어 및 회차 메타정보 로드
  Future<void> loadWords() async {
    final String wordStr = await rootBundle.loadString('assets/data/words.json');
    _allWords = (json.decode(wordStr) as List)
        .map((e) => Word.fromJson(e))
        .toList();

    final String indexStr = await rootBundle.loadString('assets/data/indexList.json');
    indexList = json.decode(indexStr) as List;

    // 데이터 로드 후 알림 전송
    notifyListeners();
  }

  List<int> get rounds {
    final roundsSet = _allWords.map((e) => e.round).toSet();
    final sorted = roundsSet.toList()..sort();
    return sorted;
  }

  List<Word> getWordsByRound(int round) {
    return _allWords.where((w) => w.round == round).toList();
  }

  String getThumbnailImageForRound(int round) {
    final int imgIndex = (round - 1);
    if (imgIndex < indexList.length && indexList[imgIndex]["img"] != null) {
      return 'assets/' + indexList[imgIndex]["img"];
    }
    return 'assets/images/default.png';
  }
}