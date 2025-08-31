class Word {
  final String name;       // 단어 이름 (예: "apple")
  final String meaning;    // 뜻 (예: "사과")
  final String img;        // 이미지 경로 (예: "images/apple.png")
  final int round;         // 회차 번호 (예: 1)

  Word({
    required this.name,
    required this.meaning,
    required this.img,
    required this.round,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      name: json['name'] ?? '',
      meaning: json['meaning'] ?? '',
      img: json['img'] ?? '',
      round: json['round'] ?? 0,
    );
  }
}