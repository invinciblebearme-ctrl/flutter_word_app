import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class IndexItem {
  final String category;
  final String name; // 예: "오늘의<br>영단어<br>[1회]"
  final String img;  // 예: "images/a.png"
  final String url;

  const IndexItem({
    required this.category,
    required this.name,
    required this.img,
    required this.url,
  });

  factory IndexItem.fromJson(Map<String, dynamic> j) => IndexItem(
    category: (j['category'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    img: (j['img'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
  );
}

class IndexRepository {
  static final IndexRepository _inst = IndexRepository._();
  IndexRepository._();
  factory IndexRepository() => _inst;

  List<IndexItem>? _cache;
  Map<int, IndexItem>? _roundMap; // round -> item 캐시

  /// JSON 로드 (assets/data/indexList.json)
  Future<List<IndexItem>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/data/indexList.json');
      final List data = jsonDecode(raw) as List;
      _cache = data.map((e) => IndexItem.fromJson(e as Map<String, dynamic>)).toList();
      _buildRoundMap();
      return _cache!;
    } catch (e) {
      // 로드 실패 시 빈 리스트 반환 (앱 크래시 방지)
      _cache = const <IndexItem>[];
      _roundMap = const <int, IndexItem>{};
      return _cache!;
    }
  }

  void _buildRoundMap() {
    final list = _cache ?? const <IndexItem>[];
    final map = <int, IndexItem>{};
    for (final it in list) {
      final r = _extractRound(it.name);
      if (r != null && !map.containsKey(r)) {
        map[r] = it;
      }
    }
    _roundMap = map;
  }

  /// "…[X회]"에서 X 추출
  int? _extractRound(String name) {
    final plain = name
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final m = RegExp(r'\[(\d+)회\]').firstMatch(plain);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// 전체 round 목록(오름차순)
  Future<List<int>> allRounds() async {
    await load();
    final rounds = _roundMap!.keys.toList()..sort();
    return rounds;
  }

  /// round에 해당하는 IndexItem
  Future<IndexItem?> findByRound(int round) async {
    await load();
    return _roundMap![round];
  }

  /// round에 해당하는 썸네일 asset 경로 (예: assets/images/a.png)
  Future<String?> getThumbnailAssetPath(int round) async {
    final it = await findByRound(round);
    if (it == null || it.img.isEmpty) return null;
    return 'assets/${it.img}';
  }

  /// round에 해당하는 원본 웹 URL
  Future<String?> getWebUrl(int round) async {
    final it = await findByRound(round);
    return it?.url;
  }

  /// 탭 라벨 등에서 쓸 수 있는 사람이 읽기 좋은 라벨
  Future<String?> labelForRound(int round) async {
    final it = await findByRound(round);
    if (it == null) return null;
    // name 내부의 <br> 제거해서 간단 라벨로
    return it.name
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 캐시 비우기(필요 시 수동 리프레시)
  void invalidate() {
    _cache = null;
    _roundMap = null;
  }
}