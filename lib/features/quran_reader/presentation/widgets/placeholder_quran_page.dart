import 'package:flutter/material.dart';

import '../../domain/models/quran_page.dart';
import '../models/reader_page_appearance.dart';
import 'reader_skeleton.dart';

class PlaceholderQuranPage extends StatelessWidget {
  const PlaceholderQuranPage({
    super.key,
    required this.page,
    required this.appearance,
  });

  final QuranPage page;
  final ReaderPageAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final sideInset = page.isLeftPage
        ? const EdgeInsets.fromLTRB(10, 10, 6, 10)
        : const EdgeInsets.fromLTRB(6, 10, 10, 10);
    return Padding(
      padding: sideInset,
      child: const ReaderSkeletonPage(),
    );
  }
}
