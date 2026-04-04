import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../models/reader_page_appearance.dart';

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
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 220 || constraints.maxWidth < 220;
        final ultraCompact = constraints.maxHeight < 160;
        final horizontalInset = ultraCompact ? 12.0 : (compact ? 16.0 : 24.0);
        final outerPadding = ultraCompact ? 10.0 : (compact ? 14.0 : 24.0);
        final sidePadding = page.isLeftPage
            ? EdgeInsets.fromLTRB(horizontalInset + 6, outerPadding,
                horizontalInset, outerPadding)
            : EdgeInsets.fromLTRB(horizontalInset, outerPadding,
                horizontalInset + 6, outerPadding);
        final sectionGap = ultraCompact ? 8.0 : (compact ? 12.0 : 18.0);
        final lineHeight = ultraCompact ? 3.0 : (compact ? 4.5 : 10.0);
        final showFooterNote = constraints.maxHeight >= 190;
        final headerVerticalPadding =
            ultraCompact ? 6.0 : (compact ? 8.0 : 10.0);
        final headerHorizontalPadding = ultraCompact ? 8.0 : 14.0;
        final headerRadius = ultraCompact ? 12.0 : 16.0;

        return Padding(
          padding: sidePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: headerHorizontalPadding,
                  vertical: headerVerticalPadding,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(headerRadius),
                  border: Border.all(
                    color: appearance.accentColor.withOpacity(0.34),
                  ),
                  color: theme.colorScheme.surface.withOpacity(
                    appearance.nightMode ? 0.22 : 0.55,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1.4,
                        color: appearance.accentColor.withOpacity(0.44),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Preview Layout',
                        overflow: TextOverflow.ellipsis,
                        style: (ultraCompact
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.labelMedium)
                            ?.copyWith(
                          color: appearance.textColor,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1.4,
                        color: appearance.accentColor.withOpacity(0.44),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: sectionGap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, lineConstraints) {
                    final slotHeight =
                        lineConstraints.maxHeight / QuranConstants.linesPerPage;
                    final adaptiveLineHeight = (slotHeight *
                            (ultraCompact ? 0.38 : (compact ? 0.44 : 0.5)))
                        .clamp(2.0, lineHeight);

                    return Column(
                      children: List<Widget>.generate(
                        QuranConstants.linesPerPage,
                        (index) => Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: _lineWidthFactor(index),
                              child: Container(
                                height: adaptiveLineHeight,
                                decoration: BoxDecoration(
                                  color: appearance.placeholderLineColor,
                                  borderRadius: BorderRadius.circular(99),
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
              if (showFooterNote) ...[
                SizedBox(height: sectionGap),
                Text(
                  'Insert authenticated Mushaf image or approved line artwork for page ${page.number}.',
                  textAlign: TextAlign.center,
                  maxLines: ultraCompact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: appearance.textColor.withOpacity(0.72),
                    height: 1.25,
                    fontSize: ultraCompact ? 9 : null,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _lineWidthFactor(int lineIndex) {
    final seed = (page.number * 11 + lineIndex * 17) % 19;
    final base = 0.76 + (seed / 100);
    if (lineIndex == 0 || lineIndex == QuranConstants.linesPerPage - 1) {
      return (base - 0.11).clamp(0.66, 0.86);
    }
    if (lineIndex % 5 == 0) {
      return (base - 0.05).clamp(0.7, 0.9);
    }
    return base.clamp(0.74, 0.95);
  }
}
