# Word Challenge Flutter (Starter)

##업데이트
- main 은 단어 깜빡이 기능만 구성
- feature/scamble-update는 스크램블 기능 구현




이 프로젝트는 업로드하신 웹앱(index.html/index.js/indexList.json)의 구조를 분석해 **Flutter**로 변환한 최소 동작 샘플입니다.

## 포함 내용
- 홈(검색+카테고리별 4열 그리드) → `assets/indexList.json`을 로드
- 카드 탭 시
  - `WordChallengeXX.html` 형태면 **네이티브 플래시카드 화면** 시도 후, 로컬 JSON이 없으면 **웹뷰**로 폴백
  - 그 외 URL은 **웹뷰**로 오픈
- `assets/words/words01.json` 샘플(10개 단어)

## 사용법
1. Flutter 3.35.1 / Dart 3.9.0 환경에서
2. 이 폴더로 이동 후 `flutter pub get`
3. `flutter run`

## 로컬 단어셋으로 완전 전환하는 법
- 각 `WordChallengeXX.html`에서 `const words = [...]` 배열을 추출해
  `assets/words/wordsXX.json`으로 저장합니다. (스키마: [{ "en": "...", "ko": "...", "img": "images/..." }, ...])
- `pubspec.yaml`의 `assets:`에 words 파일을 추가하거나, 폴더 단위 등록이면 자동 포함됩니다.
- 이미지도 `assets/images/`로 복사 후 경로를 `assets/images/...`로 바꿔 사용하세요.
