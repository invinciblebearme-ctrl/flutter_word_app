import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'; // 여기에 ChangeNotifier 있음
import '../models/word.dart';

class WordProvider extends ChangeNotifier {
  List<Word> _allWords = [];
  List<dynamic> indexList = [];

  // TODO: 실제 배포된 Cloudflare Pages 또는 GitHub Pages URL로 장소 지정 필요
  static const String _imageCdnBaseUrl = 'https://raw.githubusercontent.com/[USER]/[REPO]/main/assets/images/';
  static const bool useRemoteImages = true; // 외부 호스팅 이미지 사용 여부

  /// 단어 및 회차 메타정보 로드
  Future<void> loadWords() async {
    final String wordStr = await rootBundle.loadString('assets/data/words_800_rounds.json');
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

  String getImageUrl(String imgPath) {
    if (useRemoteImages) {
      // images/a.png -> a.webp 로 변환하여 CDN에서 로딩
      final fileName = imgPath.split('/').last.replaceAll('.png', '.webp');
      return '$_imageCdnBaseUrl$fileName';
    }
    return 'assets/$imgPath';
  }

  String getThumbnailImageForRound(int round) {
    final int imgIndex = (round - 1);
    String imgPath = 'images/default.png';
    if (imgIndex < indexList.length && indexList[imgIndex]["img"] != null) {
      imgPath = indexList[imgIndex]["img"];
    }
    return getImageUrl(imgPath);
  }
}