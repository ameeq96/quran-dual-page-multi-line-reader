import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

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
            title: Text(tr(context, 'Jump to page')),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr(context, 'Page number'),
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr(context, 'Cancel')),
              ),
              FilledButton(
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
                child: Text(tr(context, 'Go')),
              ),
            ],
          );
        },
      );
    },
  );
}
