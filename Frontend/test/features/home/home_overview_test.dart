import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_localizations.dart';
import 'package:smartagri/features/home/domain/home_overview.dart';

void main() {
  final AppLocalizations strings = lookupAppLocalizations(const Locale('fr'));
  final DateTime today = DateTime.utc(2026, 5, 20);

  group('cycleProgress', () {
    test('uses expected harvest before sowing', () {
      final CycleProgress progress = cycleProgress(
        sowingDate: DateTime.utc(2026, 5, 1),
        expectedHarvestDate: DateTime.utc(2026, 6, 1),
        today: today,
      );

      expect(progress.kind, CycleProgressKind.harvestIn);
      expect(progress.days, 12);
    });

    test('counts harvest today', () {
      final CycleProgress progress = cycleProgress(
        sowingDate: DateTime.utc(2026, 5, 1),
        expectedHarvestDate: DateTime.utc(2026, 5, 20),
        today: today,
      );

      expect(progress.kind, CycleProgressKind.harvestToday);
      expect(progress.days, 0);
    });

    test('counts late harvest without negative days', () {
      final CycleProgress progress = cycleProgress(
        expectedHarvestDate: DateTime.utc(2026, 5, 17),
        today: today,
      );

      expect(progress.kind, CycleProgressKind.harvestLate);
      expect(progress.days, 3);
    });

    test('counts elapsed sowing days', () {
      final CycleProgress progress = cycleProgress(
        sowingDate: DateTime.utc(2026, 4, 30),
        today: today,
      );

      expect(progress.kind, CycleProgressKind.sownAgo);
      expect(progress.days, 20);
    });

    test('counts sowing today', () {
      final CycleProgress progress = cycleProgress(
        sowingDate: DateTime.utc(2026, 5, 20),
        today: today,
      );

      expect(progress.kind, CycleProgressKind.sownToday);
    });

    test('counts future sowing', () {
      final CycleProgress progress = cycleProgress(
        sowingDate: DateTime.utc(2026, 5, 23),
        today: today,
      );

      expect(progress.kind, CycleProgressKind.sowingIn);
      expect(progress.days, 3);
    });

    test('reports missing dates', () {
      final CycleProgress progress = cycleProgress(today: today);

      expect(progress.kind, CycleProgressKind.noDates);
      expect(progress.days, 0);
    });

    test('compares calendar days only', () {
      final CycleProgress progress = cycleProgress(
        expectedHarvestDate: DateTime(2026, 5, 21, 0, 1),
        today: DateTime(2026, 5, 20, 23, 59),
      );

      expect(progress.kind, CycleProgressKind.harvestIn);
      expect(progress.days, 1);
    });
  });

  group('cycleProgressText', () {
    test('formats singular and plural progress', () {
      expect(
        cycleProgressText(
          strings,
          sowingDate: DateTime.utc(2026, 5, 18),
          today: today,
        ),
        'Semé il y a 2 jours',
      );
      expect(
        cycleProgressText(
          strings,
          sowingDate: DateTime.utc(2026, 5, 19),
          today: today,
        ),
        'Semé il y a 1 jour',
      );
      expect(
        cycleProgressText(
          strings,
          sowingDate: DateTime.utc(2026, 5, 25),
          today: today,
        ),
        'Semis prévu dans 5 jours',
      );
      expect(
        cycleProgressText(strings, sowingDate: today, today: today),
        "Semé aujourd'hui",
      );
      expect(
        cycleProgressText(
          strings,
          expectedHarvestDate: DateTime.utc(2026, 5, 23),
          today: today,
        ),
        'Récolte dans 3 jours',
      );
      expect(
        cycleProgressText(strings, expectedHarvestDate: today, today: today),
        "Récolte prévue aujourd'hui",
      );
      expect(
        cycleProgressText(
          strings,
          expectedHarvestDate: DateTime.utc(2026, 5, 18),
          today: today,
        ),
        'Récolte en retard de 2 jours',
      );
      expect(cycleProgressText(strings, today: today), 'Dates à renseigner');
    });
  });

  group('cycleProgressFraction', () {
    test('uses the sowing to harvest window', () {
      expect(
        cycleProgressFraction(
          sowingDate: DateTime.utc(2026, 5, 1),
          expectedHarvestDate: DateTime.utc(2026, 5, 11),
          today: DateTime.utc(2026, 5, 6),
        ),
        0.5,
      );
    });

    test('clamps outside the window', () {
      expect(
        cycleProgressFraction(
          sowingDate: DateTime.utc(2026, 5, 10),
          expectedHarvestDate: DateTime.utc(2026, 5, 20),
          today: DateTime.utc(2026, 5, 1),
        ),
        0,
      );
      expect(
        cycleProgressFraction(
          sowingDate: DateTime.utc(2026, 5, 1),
          expectedHarvestDate: DateTime.utc(2026, 5, 10),
          today: DateTime.utc(2026, 5, 20),
        ),
        1,
      );
    });

    test('returns zero without a usable window', () {
      expect(cycleProgressFraction(today: today), 0);
      expect(
        cycleProgressFraction(
          sowingDate: DateTime.utc(2026, 5, 10),
          expectedHarvestDate: DateTime.utc(2026, 5, 10),
          today: today,
        ),
        0,
      );
      expect(
        cycleProgressFraction(
          sowingDate: DateTime.utc(2026, 5, 10),
          expectedHarvestDate: DateTime.utc(2026, 5, 1),
          today: today,
        ),
        0,
      );
    });
  });

  group('firstNameFromFullName', () {
    test('keeps the first word and uppercases it', () {
      expect(
        firstNameFromFullName('Amina Diallo', fallback: 'Agriculteur'),
        'AMINA',
      );
      expect(
        firstNameFromFullName('  Aïcha   Maïga ', fallback: 'Agriculteur'),
        'AÏCHA',
      );
      expect(
        firstNameFromFullName('ɓello ɗan', fallback: 'Agriculteur'),
        'ƁELLO',
      );
    });

    test('falls back for empty values', () {
      expect(
        firstNameFromFullName(null, fallback: 'Agriculteur'),
        'Agriculteur',
      );
      expect(firstNameFromFullName('', fallback: 'Agriculteur'), 'Agriculteur');
      expect(
        firstNameFromFullName('   ', fallback: 'Agriculteur'),
        'Agriculteur',
      );
    });
  });
}
