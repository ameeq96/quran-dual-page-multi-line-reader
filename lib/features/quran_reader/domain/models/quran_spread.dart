import 'quran_page.dart';

class QuranSpread {
  const QuranSpread({
    required this.index,
    required this.rightPage,
    required this.leftPage,
  });

  final int index;
  final QuranPage rightPage;
  final QuranPage leftPage;
}
