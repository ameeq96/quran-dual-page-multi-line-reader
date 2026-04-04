import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../models/reader_page_appearance.dart';

class AuthenticQuranPage extends StatelessWidget {
  const AuthenticQuranPage({
    super.key,
    required this.page,
    required this.appearance,
  });

  final QuranPage page;
  final ReaderPageAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linesByNumber = <int, String>{
      for (final line in page.lines) line.lineNumber: line.text,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 260 || constraints.maxWidth < 250;
        final ultraCompact =
            constraints.maxHeight < 190 || constraints.maxWidth < 180;
        final outerPadding = ultraCompact ? 10.0 : (compact ? 14.0 : 22.0);
        final innerPadding = ultraCompact ? 8.0 : (compact ? 10.0 : 16.0);
        final topBandHeight = ultraCompact ? 18.0 : (compact ? 22.0 : 28.0);
        final dividerGap = ultraCompact ? 8.0 : (compact ? 10.0 : 14.0);
        final sidePadding = page.isLeftPage
            ? EdgeInsets.fromLTRB(
                outerPadding + 4,
                outerPadding,
                innerPadding,
                outerPadding,
              )
            : EdgeInsets.fromLTRB(
                innerPadding,
                outerPadding,
                outerPadding + 4,
                outerPadding,
              );

        return Padding(
          padding: sidePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: topBandHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1.2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              appearance.accentColor.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: ultraCompact ? 14 : 20,
                        height: 6,
                        decoration: BoxDecoration(
                          color: appearance.accentColor.withOpacity(0.32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1.2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              appearance.accentColor.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: dividerGap),
              Expanded(
                child: Column(
                  children: List<Widget>.generate(
                    QuranConstants.mushafTextLineSlots,
                    (index) {
                      final lineNumber = index + 1;
                      final text = linesByNumber[lineNumber];
                      return Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: text == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        text,
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                        softWrap: false,
                                        textAlign: TextAlign.center,
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: appearance.textColor,
                                          fontSize: ultraCompact
                                              ? 18
                                              : (compact ? 22 : 28),
                                          height: 1.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
