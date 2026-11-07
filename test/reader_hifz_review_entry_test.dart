import 'package:flutter_test/flutter_test.dart';

import '../lib/features/quran_reader/domain/models/reader_growth_models.dart';
import '../lib/features/quran_reader/domain/models/reader_settings.dart';

ReaderHifzReviewEntry entry(HifzPageStrength strength, String reviewedAt) {
  return ReaderHifzReviewEntry(
    pageNumber: 14,
    edition: MushafEdition.lines17,
    strength: strength,
    updatedAtIso: reviewedAt,
    reviewCount: 2,
  );
}

void main() {
  group('Hifz revision calendar', () {
    test('uses one, three and seven local calendar days', () {
      final reviewed = DateTime(2026, 11, 7, 23, 59);
      final now = DateTime(2026, 11, 8, 0, 1);
      for (final (strength, interval) in [
        (HifzPageStrength.weak, 1),
        (HifzPageStrength.steady, 3),
        (HifzPageStrength.strong, 7),
      ]) {
        final review = entry(strength, reviewed.toIso8601String());
        expect(review.reviewIntervalDays, interval);
        expect(review.reviewDueDate(now: now), DateTime(2026, 11, 7 + interval));
        expect(review.daysUntilReview(now: now), interval - 1);
        expect(review.isDueForReview(now: now), interval == 1);
      }
    });

    test('distinguishes overdue, due today and upcoming at midnight', () {
      final review = entry(HifzPageStrength.steady,
          DateTime(2026, 11, 7, 21).toIso8601String());
      expect(review.daysUntilReview(now: DateTime(2026, 11, 9, 23, 59)), 1);
      expect(review.daysUntilReview(now: DateTime(2026, 11, 10, 23, 59)), 0);
      expect(review.daysUntilReview(now: DateTime(2026, 11, 11)), -1);
      expect(review.isDueForReview(now: DateTime(2026, 11, 11)), isTrue);
    });

    test('handles month, leap-day and year transitions', () {
      final cases = [
        (DateTime(2024, 2, 28, 23), DateTime(2024, 2, 29)),
        (DateTime(2026, 2, 28, 23), DateTime(2026, 3, 1)),
        (DateTime(2026, 12, 31, 23), DateTime(2027, 1, 1)),
      ];
      for (final (reviewed, expected) in cases) {
        final review = entry(HifzPageStrength.weak, reviewed.toIso8601String());
        expect(review.reviewDueDate(now: expected), expected);
        expect(review.daysUntilReview(now: expected), 0);
      }
    });

    test('converts stored UTC and offset instants to the local review day', () {
      for (final stamp in ['2026-11-07T23:30:00.000Z',
        '2026-11-07T00:30:00.000+05:00']) {
        final reviewed = DateTime.parse(stamp).toLocal();
        final expected = DateTime(reviewed.year, reviewed.month, reviewed.day + 3);
        final review = entry(HifzPageStrength.steady, stamp);
        expect(review.reviewDueDate(now: expected), expected);
        expect(review.daysUntilReview(now: expected), 0);
      }
    });

    test('missing and invalid legacy review dates are due today', () {
      final now = DateTime(2026, 11, 7, 18, 30);
      for (final stamp in ['', 'invalid', '2026-02-30T10:00:00Z',
        '2026-11-07T25:00:00Z', '2026-11-07T10:00:00+99:00']) {
        final review = entry(HifzPageStrength.strong, stamp);
        expect(review.reviewDueDate(now: now), DateTime(2026, 11, 7));
        expect(review.daysUntilReview(now: now), 0);
        expect(review.isDueForReview(now: now), isTrue);
      }
    });

    test('derives schedule without changing serialized data or edition', () {
      final review = entry(HifzPageStrength.strong,
          DateTime(2026, 11, 7, 14).toIso8601String());
      final payload = review.toJson();
      final restored = ReaderHifzReviewEntry.fromJson(payload);
      expect(restored.toJson(), payload);
      expect(restored.edition, MushafEdition.lines17);
      expect(restored.reviewCount, 2);
      expect(restored.reviewDueDate(now: DateTime(2026, 11, 7)),
          DateTime(2026, 11, 14));
      expect(payload.keys, isNot(contains('dueAt')));
      expect(ReaderHifzReviewEntry.fromJson({'pageNumber': 2})
          .isDueForReview(now: DateTime(2026, 11, 7)), isTrue);
    });
  });
}
