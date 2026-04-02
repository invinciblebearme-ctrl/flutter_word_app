import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
// ✅ 음성 인식(STT)
import 'package:speech_to_text/speech_to_text.dart' as stt;
// ✅ 권한 요청
import 'package:permission_handler/permission_handler.dart';

class FlashcardScreen extends StatefulWidget {
  final int round; // 1~80
  const FlashcardScreen({super.key, required this.round});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  int currentIndex = 0;

  // 깜빡이(텍스트 전환만)
  bool _showEnglish = true; // true: 영어, false: 한글 뜻
  Timer? _flipTimer;

  final FlutterTts _tts = FlutterTts();
  static const Duration kFlipInterval = Duration(milliseconds: 1200);

  // ✅ STT 관련
  late final stt.SpeechToText _speech;
  bool _speechReady = false;
  bool _isListening = false;
  String _heard = '';
  int? _score; // 0~100
  bool get _hasLevel => _score != null && _score! >= 25;

  // ✅ TTS 진행 상태
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    _startTimers();
    _initSpeech(); // 초기화 시도
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true); // 재생 완료까지 대기
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (s) => debugPrint('STT status: $s'),
        onError: (e) => debugPrint('STT error: $e'),
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechReady = false;
    }
  }

  void _startTimers() {
    _flipTimer?.cancel();
    _flipTimer = Timer.periodic(kFlipInterval, (_) {
      if (!mounted) return;
      setState(() => _showEnglish = !_showEnglish);
    });
  }

  void _resetFlipState() {
    _showEnglish = true;
  }

  Future<void> _speakWord(String text) async {
    if (!mounted) return;
    setState(() => _isSpeaking = true);
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  // ✅ 다음 회차로 이동 (pushReplacement)
  void _goToNextRoundIfAny() {
    final provider = context.read<WordProvider>();
    final rounds = provider.rounds;
    final maxRound = rounds.isNotEmpty ? rounds.reduce((a, b) => a > b ? a : b) : 80;
    final nextRound = widget.round + 1;

    if (nextRound <= maxRound) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FlashcardScreen(round: nextRound)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마지막 회차입니다.')),
      );
    }
  }

  // ✅ 마지막 카드에서 "다음 회차로 넘어갈까요?" 확인 후 이동
  Future<void> _confirmAndMaybeGoNextRound() async {
    final nextRound = widget.round + 1;
    final bool go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('다음 회차로 이동'),
        content: Text('현재 회차의 마지막 단어입니다.\n다음 회차(${nextRound}회)로 넘어갈까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('예'),
          ),
        ],
      ),
    ) ??
        false;

    if (go) {
      _goToNextRoundIfAny();
    } else {
      setState(() {
        _resetFlipState();
      });
    }
  }

  void _nextCard(int len) {
    // 🔒 듣기/녹음 중에는 이동 금지
    if (_isSpeaking || _isListening) return;

    if (currentIndex < len - 1) {
      setState(() {
        currentIndex++;
        _resetFlipState();
        _heard = '';
        _score = null;
      });
    } else {
      _confirmAndMaybeGoNextRound();
    }
  }

  void _prevCard() {
    // 🔒 듣기/녹음 중에는 이동 금지
    if (_isSpeaking || _isListening) return;

    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _resetFlipState();
        _heard = '';
        _score = null;
      });
    }
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  // ✅ 마이크 권한 체크 & 요청
  Future<bool> _ensureMicPermission() async {
    if (await Permission.microphone.isGranted) return true;
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 > 앱 권한에서 마이크를 허용해 주세요.')),
      );
      await openAppSettings();
    } else {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다.')),
      );
    }
    return false;
  }

  // ===== 점수 계산 로직 =====
  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  double _levenshteinSimilarity(String a, String b) {
    final m = a.length, n = b.length;
    if (m == 0 && n == 0) return 1.0;
    if (m == 0 || n == 0) return 0.0;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    final dist = dp[m][n];
    final maxLen = m > n ? m : n;
    return (1.0 - dist / maxLen).clamp(0.0, 1.0);
  }

  int _scorePronunciation(String expectedRaw, String recognizedRaw) {
    final expected = _norm(expectedRaw);
    final recAll = _norm(recognizedRaw);
    if (expected.isEmpty || recAll.isEmpty) return 0;

    double best = _levenshteinSimilarity(expected, recAll);

    final tokens = RegExp(r'[a-z]+')
        .allMatches(recognizedRaw.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    for (final t in tokens) {
      final sim = _levenshteinSimilarity(expected, _norm(t));
      if (sim > best) best = sim;
    }
    for (int i = 0; i < tokens.length - 1; i++) {
      final bigram = '${tokens[i]}${tokens[i + 1]}';
      final sim = _levenshteinSimilarity(expected, _norm(bigram));
      if (sim > best) best = sim;
    }

    int score = (best * 100).round();
    if (expected.length <= 3 && score > 0 && score < 100) {
      score = (score * 0.85 + 15).clamp(0, 100).round();
    }
    return score;
  }

  // ===== 레벨 매핑 =====
  // 점수 → 레벨(라벨/아이콘/색상)
  (_Level, IconData, Color) _levelFromScore(int? score) {
    if (score == null) {
      return (_Level.none, Icons.block, Colors.grey);
    }
    if (score >= 90) return (_Level.excellent, Icons.sentiment_very_satisfied, Colors.greenAccent);
    if (score >= 75) return (_Level.good, Icons.sentiment_satisfied, Colors.lightGreen);
    if (score >= 50) return (_Level.fair, Icons.sentiment_neutral, Colors.amber);
    if (score >= 25) return (_Level.poor, Icons.sentiment_dissatisfied, Colors.deepOrangeAccent);
    return (_Level.none, Icons.sentiment_very_dissatisfied, Colors.grey);
  }

  String _labelForLevel(_Level lv) {
    switch (lv) {
      case _Level.excellent:
        return 'excellent';
      case _Level.good:
        return 'good';
      case _Level.fair:
        return 'fair';
      case _Level.poor:
        return 'poor';
      case _Level.none:
        return 'none';
    }
  }

  // ===== 마이크/채점 =====
  Future<void> _listenAndScore(String expectedWord) async {
    final ok = await _ensureMicPermission();
    if (!ok) return;

    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음성 인식을 초기화할 수 없어요. (엔진/권한/오디오 입력 확인)')),
        );
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _heard = '';
      _score = null;
      _isListening = true;
    });

    await _speech.listen(
      localeId: 'en_US',
      onResult: (result) {
        _heard = result.recognizedWords;
        if (result.finalResult) {
          _finishScoring(expectedWord);
        } else {
          setState(() {});
        }
      },
      listenFor: const Duration(seconds: 3),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
    );

    Future.delayed(const Duration(seconds: 4), () async {
      if (_isListening) {
        await _speech.stop();
        _finishScoring(expectedWord);
      }
    });
  }

  void _finishScoring(String expectedWord) {
    final score = _scorePronunciation(expectedWord, _heard);
    setState(() {
      _score = score;
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordProvider>();
    final List<Word> wordList = provider.getWordsByRound(widget.round);

    if (wordList.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentIndex >= wordList.length) currentIndex = 0;
    final word = wordList[currentIndex];

    final bool busy = _isListening || _isSpeaking;

    // 레벨/아이콘/색상 계산
    final (level, levelIcon, levelColor) = _levelFromScore(_score);
    final levelLabel = _labelForLevel(level);

    return Scaffold(
      appBar: AppBar(
        title: Text(' ${widget.round}회 - 단어깜빡이'),
        actions: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Text('발음 듣기', style: TextStyle(color: Colors.white)),
            ),
          ),
          IconButton(
            tooltip: '영어 발음 듣기',
            icon: const Icon(Icons.volume_up),
            onPressed: busy ? null : () => _speakWord(word.name),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${currentIndex + 1} / ${wordList.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 1.0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 500),
                    child: Card(
                      color: Colors.grey[900],
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const double textBoxHeight = 96.0;
                            const double gap = 20.0;
                            const double innerGap = 12.0;

                            // 컨트롤 고정 높이(버튼+점수칩+레벨+인식)
                            const double controlsHeight = 172.0;

                            final double baseSide = [
                              constraints.maxWidth * 0.8,
                              constraints.maxHeight * 0.55,
                              180.0,
                            ].reduce((a, b) => a < b ? a : b);

                            final double target = baseSide * 2.0;
                            final double verticalBudget = (constraints.maxHeight
                                - textBoxHeight
                                - gap
                                - innerGap
                                - controlsHeight)
                                .clamp(140.0, double.infinity);

                            final double side = [
                              target,
                              constraints.maxWidth,
                              verticalBudget,
                            ].reduce((a, b) => a < b ? a : b);

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox.square(
                                    dimension: side,
                                    child: WordProvider.useRemoteImages
                                        ? Image.network(
                                      provider.getImageUrl(word.img),
                                      key: ValueKey('img_${widget.round}_$currentIndex'),
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: const Color(0xFF2A2744),
                                          child: const Center(
                                            child: CircularProgressIndicator(color: Colors.white70),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        width: side,
                                        height: side,
                                        alignment: Alignment.center,
                                        color: const Color(0xFF2A2744),
                                        child: const Icon(Icons.broken_image,
                                            size: 48, color: Colors.white70),
                                      ),
                                    )
                                        : Image.asset(
                                      'assets/${word.img}',
                                      key: ValueKey('img_${widget.round}_$currentIndex'),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: side,
                                        height: side,
                                        alignment: Alignment.center,
                                        color: const Color(0xFF2A2744),
                                        child: const Icon(Icons.broken_image,
                                            size: 48, color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: gap),
                                SizedBox(
                                  height: textBoxHeight,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 500),
                                      transitionBuilder: (child, anim) =>
                                          FadeTransition(opacity: anim, child: child),
                                      child: _showEnglish
                                          ? Text(
                                        word.name,
                                        key: ValueKey('en_${widget.round}_$currentIndex'),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Text(
                                        word.meaning,
                                        key: ValueKey('ko_${widget.round}_$currentIndex'),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: innerGap),

                                // ✨ 세로(Column) 배치: 발음 입력 → 점수칩 → 레벨(아이콘+텍스트) → 인식 단어
                                SizedBox(
                                  height: controlsHeight,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 1) 발음 입력 버튼
                                      ElevatedButton.icon(
                                        onPressed: busy ? null : () => _listenAndScore(word.name),
                                        icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                                        label: Text(_isListening ? '그만하기' : '발음 입력'),
                                      ),

                                      const SizedBox(height: 10),

                                      // 2) 점수(Chip) — 고정 자리 확보(높이 32)
                                      SizedBox(
                                        height: 32,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: (_score != null)
                                              ? Chip(
                                            key: const ValueKey('scoreChip'),
                                            label: Text(
                                              '점수: $_score',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            backgroundColor: Colors.blueGrey,
                                          )
                                              : Opacity(
                                            key: const ValueKey('scorePlaceholder'),
                                            opacity: 0.0,
                                            child: Chip(
                                              label: Text(
                                                '점수: --',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                              backgroundColor: Colors.blueGrey,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // 3) 레벨(아이콘+텍스트) — 고정 자리 확보(높이 28)
                                      SizedBox(
                                        height: 28,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: _hasLevel
                                              ? Row(
                                            key: const ValueKey('levelVisible'),
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(levelIcon, size: 20, color: levelColor),
                                              const SizedBox(width: 6),
                                              Text(
                                                '$levelLabel',
                                                style: TextStyle(
                                                  color: levelColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                              : const SizedBox(
                                            key: ValueKey('levelHidden'),
                                            // 빈 공간(28px 높이 유지)만 남겨 레이아웃 점프 방지
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // 4) 인식 단어 — 고정 높이(20)
                                      SizedBox(
                                        height: 20,
                                        child: Text(
                                          _heard.isNotEmpty ? '인식: $_heard' : '',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 하단 컨트롤
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: busy ? null : _prevCard,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('이전'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_flipTimer?.isActive == true) {
                      _flipTimer?.cancel();
                    } else {
                      _startTimers();
                    }
                    setState(() {});
                  },
                  icon: Icon((_flipTimer?.isActive == true)
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill),
                  label: Text((_flipTimer?.isActive == true) ? '일시정지' : '재시작'),
                ),
                ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _nextCard(
                    context.read<WordProvider>().getWordsByRound(widget.round).length,
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('다음'),
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

// 점수 등급 Enum
enum _Level { excellent, good, fair, poor, none }