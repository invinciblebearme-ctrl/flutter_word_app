import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../screen/flashcard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  List<int> _filteredRounds = [];
  Timer? _debounce;

  static const int _tabsCount = 4;
  late final TabController _tabController;

  bool get _isSearching => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tabController = TabController(length: _tabsCount, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {}); // 탭 변경 시 재빌드
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<WordProvider>(context, listen: false);
      await provider.loadWords();
      if (!mounted) return;
      setState(() {
        _filteredRounds = provider.rounds; // 초기엔 전체
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// 검색: 검색 중이면 4개 탭 모두 같은 결과가 보이도록 _filteredRounds 자체를 갱신만 함
  void _filterRounds(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      final provider = Provider.of<WordProvider>(context, listen: false);
      final rounds = provider.rounds;

      if (query.trim().isEmpty) {
        setState(() => _filteredRounds = rounds);
        return;
      }
      final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
      final next = rounds.where((r) => r.toString().contains(digits)).toList();
      setState(() => _filteredRounds = next);
    });
  }

  /// rounds를 4등분하여 각 탭의 [start, end] 범위를 계산
  List<List<int>> _computeRanges(List<int> rounds) {
    if (rounds.isEmpty) {
      // 자리표시자 (1~80 가정)
      return const [
        [1, 20],
        [21, 40],
        [41, 60],
        [61, 80],
      ];
    }
    final sorted = [...rounds]..sort();
    final total = sorted.length;

    // 기본 4등분 (대략 20개씩)
    final per = (total / _tabsCount).ceil();
    final ranges = <List<int>>[];
    for (int i = 0; i < _tabsCount; i++) {
      final startIdx = i * per;
      final endIdx = (startIdx + per - 1).clamp(0, total - 1);
      final start = startIdx < total ? sorted[startIdx] : sorted.last;
      final end = endIdx < total ? sorted[endIdx] : sorted.last;
      ranges.add([start, end]);
    }

    // rounds가 정확히 1..80이면 보기 좋게 고정
    if (sorted.first == 1 && sorted.last == 80 && total == 80) {
      return const [
        [1, 20],
        [21, 40],
        [41, 60],
        [61, 80],
      ];
    }
    return ranges;
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                hintText: '회차로 찾기',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterRounds,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              _controller.clear();
              _filterRounds('');
              FocusScope.of(context).unfocus();
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  /// 실제 그리드 (탭별로 넘겨준 리스트를 그대로 그림)
  Widget _buildGrid({
    required List<int> roundsForTab,
    required WordProvider provider,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final round = roundsForTab[index];
            final imgPath = provider.getThumbnailImageForRound(round);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(round: round),
                  ),
                );
              },
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      imgPath,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey[800],
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, color: Colors.white70, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '영단어',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '[$round회]',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: roundsForTab.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WordProvider>(context);

    // 초기 동기화: provider.rounds 로드 이후 첫 화면
    if (_filteredRounds.isEmpty && provider.rounds.isNotEmpty) {
      _filteredRounds = provider.rounds;
    }

    final ranges = _computeRanges(provider.rounds);

    return DefaultTabController(
      length: _tabsCount,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // 검색바
              _buildSearchBar(),

              // 탭바: 검색 중이면 혼동 방지를 위해 레이블을 "검색 결과"로 통일
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicator: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: List.generate(_tabsCount, (i) {
                    if (_isSearching) return const Tab(text: '검색 결과');
                    final r = ranges[i];
                    return Tab(text: '${r[0]}–${r[1]}');
                  }),
                ),
              ),

              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '검색 중: 모든 탭에 동일한 결과가 표시됩니다 (${_filteredRounds.length}건)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 8),

              // 탭 내용
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabsCount, (i) {
                    final r = ranges[i];

                    // 검색 중: 4개 탭 전부 동일한 결과(_filteredRounds) 사용
                    // 평상시: 각 탭 범위만 필터하여 표시
                    final listForThisTab = _isSearching
                        ? _filteredRounds
                        : _filteredRounds.where((x) => x >= r[0] && x <= r[1]).toList();

                    return CustomScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            child: Center(
                              child: Text(
                                '오늘의 영단어로 실력 Up',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildGrid(
                          roundsForTab: listForThisTab,
                          provider: provider,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}