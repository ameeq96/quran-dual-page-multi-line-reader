import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import 'reader_app_bar.dart';

Future<int?> showJumpToPageDialog(
  BuildContext context, {
  required int currentPage,
  required int maxPage,
}) {
  final controller = TextEditingController(text: currentPage.toString());
  String? errorText;

  return showDialog<int>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            icon: const Center(
              child: ReaderAccentBadge(
                icon: Icons.menu_book_rounded,
                size: 48,
              ),
            ),
            title: Text(
              tr(context, 'Jump to page'),
              textAlign: TextAlign.center,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                labelText: tr(context, 'Page number'),
                prefixIcon: const Icon(Icons.tag_rounded),
                errorMaxLines: 3,
                hintText: tr(context, '1 - $maxPage'),
                errorText: errorText == null ? null : tr(context, errorText!),
              ),
              onSubmitted: (_) {
                final page = int.tryParse(controller.text);
                if (page == null || page < 1 || page > maxPage) {
                  setState(() {
                    errorText = 'Enter a page from 1 to $maxPage.';
                  });
                  return;
                }
                Navigator.of(context).pop(page);
              },
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(tr(context, 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final page = int.tryParse(controller.text);
                        if (page == null || page < 1 || page > maxPage) {
                          setState(() {
                            errorText = 'Enter a page from 1 to $maxPage.';
                          });
                          return;
                        }
                        Navigator.of(context).pop(page);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(tr(context, 'Go')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}
