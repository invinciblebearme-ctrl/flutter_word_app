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
  late TextEditingController _controller;
  late TabController _tabController;

  // 필터된 회차(검색 결과). 기본은 전체 회차.
  List<int> _filteredRounds = [];

  // 탭 구간 정의: 0번째는 '전체'
  final List<List<int>> tabs = const [
    [1, 80],   // 전체
    [1, 20],
    [21, 40],
    [41, 60],
    [61, 80],
  ];

  bool get _isSearching => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tabController = TabController(length: 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<WordProvider>(context, listen: false);
      await provider.loadWords();
      setState(() {
        _filteredRounds = provider.rounds; // 전체로 초기화
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _filterRounds(String query) {
    final provider = Provider.of<WordProvider>(context, listen: false);
    final rounds = provider.rounds;

    if (query.isEmpty) {
      _filteredRounds = rounds;
    } else {
      final onlyDigits = query.replaceAll(RegExp(r'[^0-9]'), '');
      _filteredRounds = rounds
          .where((r) => r.toString().contains(onlyDigits))
          .toList();

      // ✅ 검색 시 자동으로 '전체' 탭(인덱스 0)으로 이동
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
    }
    setState(() {});
  }

  Widget _buildGrid(BuildContext context, List<int> rounds) {
    final provider = Provider.of<WordProvider>(context, listen: false);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rounds.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 24,
        childAspectRatio: 0.65,
      ),
      itemBuilder: (context, index) {
        final round = rounds[index];
        final imgPath = provider.getThumbnailImageForRound(round);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FlashcardScreen(round: round)),
            );
          },
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: WordProvider.useRemoteImages
                    ? Image.network(
                  imgPath,
                  width: 65,
                  height: 65,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 65,
                      height: 65,
                      color: Colors.grey[900],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 65,
                    height: 65,
                    color: Colors.grey,
                    child: const Icon(Icons.broken_image),
                  ),
                )
                    : Image.asset(
                  imgPath,
                  width: 65,
                  height: 65,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 65,
                    height: 65,
                    color: Colors.grey,
                    child: const Icon(Icons.broken_image),
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
                ),
              ),
              Text(
                '[$round회]',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WordProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 검색
            Padding(
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
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () {
                        _controller.clear();
                        _filterRounds('');
                        // 초기화 시에도 전체 탭으로
                        if (_tabController.index != 0) {
                          _tabController.animateTo(0);
                        }
                      },
                      child: const Text('초기화'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),

            const Text(
              '오늘의 영단어로 실력 Up',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            // 탭바
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorWeight: 3,
              indicatorColor: Colors.blue,
              labelStyle: const TextStyle(  // ✅ 선택된 탭 글자 스타일
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(  // ✅ 선택되지 않은 탭 글자 스타일
                fontSize: 12,
              ),
              tabs: List.generate(tabs.length, (i) {
                if (i == 0) return const Tab(text: '전체');
                final r = tabs[i];
                return Tab(text: '${r[0]}–${r[1]}');
              }),
            ),

            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(tabs.length, (i) {
                  // ✅ 검색 중에는 "모든 탭"에서 동일하게 전체 검색 결과를 보여줌
                  if (_isSearching) {
                    return _buildGrid(context, _filteredRounds);
                  }

                  // ✅ 검색이 아닐 때만 탭 범위 적용
                  if (i == 0) {
                    // 전체 탭: 전체 결과(_filteredRounds) 표시
                    return _buildGrid(context, _filteredRounds);
                  } else {
                    // 범위 탭: 해당 구간만 표시
                    final r = tabs[i];
                    final roundsInRange = _filteredRounds
                        .where((x) => x >= r[0] && x <= r[1])
                        .toList();
                    return _buildGrid(context, roundsInRange);
                  }
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}