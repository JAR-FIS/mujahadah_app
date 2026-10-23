import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mujahadah/models/v2_onboarding_model.dart';

void main() {
  group('V2OnboardingModel Unit Tests', () {
    test('1. Supported languages list contains id, ms, en, ar', () {
      expect(
        V2OnboardingModel.supportedLanguages,
        containsAll(['id', 'ms', 'en', 'ar']),
      );
      expect(V2OnboardingModel.supportedLanguages.length, equals(4));
    });

    test(
        '2. RTL detection correctly identifies Arabic as RTL and others as LTR',
        () {
      expect(V2OnboardingModel.isRtl('ar'), isTrue);
      expect(V2OnboardingModel.isRtl('AR'), isTrue);
      expect(V2OnboardingModel.isRtl('id'), isFalse);
      expect(V2OnboardingModel.isRtl('en'), isFalse);
      expect(V2OnboardingModel.isRtl('ms'), isFalse);
      expect(V2OnboardingModel.isRtl(null), isFalse);
      expect(V2OnboardingModel.isRtl(''), isFalse);
    });

    test('3. Language normalization maps valid codes and falls back to id', () {
      expect(V2OnboardingModel.normalizeLanguage('id'), equals('id'));
      expect(V2OnboardingModel.normalizeLanguage('ms'), equals('ms'));
      expect(V2OnboardingModel.normalizeLanguage('en'), equals('en'));
      expect(V2OnboardingModel.normalizeLanguage('ar'), equals('ar'));
      expect(V2OnboardingModel.normalizeLanguage('ID '), equals('id'));
      expect(V2OnboardingModel.normalizeLanguage('fr'), equals('id'));
      expect(V2OnboardingModel.normalizeLanguage(null), equals('id'));
      expect(V2OnboardingModel.normalizeLanguage(''), equals('id'));
    });

    test(
        '4. V2OnboardingStringsId provides exactly 5 screens with exact approved titles and business rules',
        () {
      const strings = V2OnboardingStringsId();
      expect(strings.languageCode, equals('id'));
      expect(strings.isFullyLocalized, isTrue);
      expect(strings.isRtl, isFalse);
      expect(strings.pages.length, equals(5));
      expect(strings.fallbackNotice, isEmpty);

      // Screen 1: Selamat Datang di Mujahadah
      expect(strings.pages[0].pageIndex, equals(0));
      expect(strings.pages[0].badge, equals('Aplikasi Mujahadah'));
      expect(strings.pages[0].title, equals('Selamat Datang di Mujahadah'));
      expect(
        strings.pages[0].body,
        contains('membantumu membangun dan menjaga konsistensi (istiqomah)'),
      );
      expect(strings.pages[0].icon, equals(Icons.mosque_outlined));
      expect(strings.pages[0].isBodyProvisional, isTrue);

      // Screen 2: Bangun Istiqomah dengan Target yang Jelas
      expect(strings.pages[1].pageIndex, equals(1));
      expect(strings.pages[1].badge, equals('Target Bertahap'));
      expect(
        strings.pages[1].title,
        equals('Bangun Istiqomah dengan Target yang Jelas'),
      );
      expect(
        strings.pages[1].body,
        contains(
            '40, 60, 90, 100 hari, atau tentukan target kustom minimal 40 hari'),
      );
      expect(strings.pages[1].icon, equals(Icons.flag_outlined));
      expect(strings.pages[1].isBodyProvisional, isTrue);

      // Screen 3: Check-in, Ingat, dan Jangan Terlewat
      expect(strings.pages[2].pageIndex, equals(2));
      expect(strings.pages[2].badge, equals('Disiplin Waktu'));
      expect(
        strings.pages[2].title,
        equals('Check-in, Ingat, dan Jangan Terlewat'),
      );
      expect(
        strings.pages[2].body,
        contains('hari operasional (03:00–02:59)'),
      );
      expect(strings.pages[2].icon, equals(Icons.alarm_on_outlined));
      expect(strings.pages[2].isBodyProvisional, isTrue);

      // Screen 4: Muhasabah, Bukan Sekadar Streak
      expect(strings.pages[3].pageIndex, equals(3));
      expect(strings.pages[3].badge, equals('Evaluasi Diri'));
      expect(
        strings.pages[3].title,
        equals('Muhasabah, Bukan Sekadar Streak'),
      );
      expect(
        strings.pages[3].body,
        contains('muhasabah dengan mencatat alasan'),
      );
      expect(strings.pages[3].icon, equals(Icons.self_improvement_outlined));
      expect(strings.pages[3].isBodyProvisional, isTrue);

      // Screen 5: P1-01 Piagam issued upon program target completion, not every milestone
      expect(strings.pages[4].pageIndex, equals(4));
      expect(strings.pages[4].badge, equals('Apresiasi & Rekam Jejak'));
      expect(
        strings.pages[4].title,
        equals('Lihat Perjalanan dan Rayakan Milestone'),
      );
      expect(
        strings.pages[4].body,
        contains(
            'raih Piagam Istiqomah saat berhasil menyelesaikan target program'),
      );
      expect(
        strings.pages[4].body.contains('di setiap pencapaian milestone'),
        isFalse,
        reason:
            'Piagam is awarded upon target completion, not at every interim milestone',
      );
      expect(strings.pages[4].icon, equals(Icons.workspace_premium_outlined));
      expect(strings.pages[4].isBodyProvisional, isTrue);
    });

    test(
        '5. V2OnboardingStringsFallback discloses pending translation and provides honest notice',
        () {
      const fallbackEn = V2OnboardingStringsFallback(languageCode: 'en');
      expect(fallbackEn.languageCode, equals('en'));
      expect(fallbackEn.isFullyLocalized, isFalse);
      expect(fallbackEn.isRtl, isFalse);
      expect(fallbackEn.pages.length, equals(5));
      expect(fallbackEn.pages[0].title, equals('Selamat Datang di Mujahadah'));
      expect(
        fallbackEn.fallbackNotice,
        equals(
          'Terjemahan bahasa ini sedang disiapkan. Teks sementara ditampilkan dalam Bahasa Indonesia.',
        ),
      );

      const fallbackAr = V2OnboardingStringsFallback(languageCode: 'ar');
      expect(fallbackAr.languageCode, equals('ar'));
      expect(fallbackAr.isFullyLocalized, isFalse);
      expect(fallbackAr.isRtl, isTrue);
      expect(fallbackAr.nextLabel, equals('Lanjut'));
      expect(fallbackAr.fallbackNotice, isNotEmpty);
    });

    test('6. Registry stringsFor resolves proper implementation for all codes',
        () {
      final idStrings = V2OnboardingModel.stringsFor('id');
      expect(idStrings, isA<V2OnboardingStringsId>());

      final enStrings = V2OnboardingModel.stringsFor('en');
      expect(enStrings, isA<V2OnboardingStringsFallback>());
      expect(enStrings.languageCode, equals('en'));

      final arStrings = V2OnboardingModel.stringsFor('ar');
      expect(arStrings, isA<V2OnboardingStringsFallback>());
      expect(arStrings.isRtl, isTrue);

      final unknownStrings = V2OnboardingModel.stringsFor('unknown');
      expect(unknownStrings, isA<V2OnboardingStringsId>());
    });
  });
}
