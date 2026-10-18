import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mujahadah/models/ibadah_model.dart';
import 'package:mujahadah/models/program_model.dart';
import 'package:mujahadah/models/user_model.dart';
import 'package:mujahadah/theme/app_theme.dart';
import 'package:mujahadah/views/widgets/reason_badge.dart';

void main() {
  group('Baseline Model Tests', () {
    test('UserModel instantiation smoke test', () {
      final user = UserModel(
        nama: 'Ahmad',
        umur: 25,
        pekerjaan: 'Engineer',
        alamat: 'Jakarta',
      );

      expect(user.nama, 'Ahmad');
      expect(user.umur, 25);
      expect(user.pekerjaan, 'Engineer');
      expect(user.alamat, 'Jakarta');
    });

    test('ProgramModel default values and fields test', () {
      final now = DateTime.now();
      final program = ProgramModel(
        id: 'prog-001',
        namaIbadah: 'Tahajjud',
        targetHari: 40,
        tglMulai: now,
        jamPengingat: '03:30',
        status: 'ACTIVE',
      );

      expect(program.id, 'prog-001');
      expect(program.namaIbadah, 'Tahajjud');
      expect(program.targetHari, 40);
      expect(program.hariBerjalan, 0);
      expect(program.status, 'ACTIVE');
      expect(program.alasanGagal, isNull);
    });

    test('IbadahModel default values test', () {
      final ibadah = IbadahModel(
        id: 'ibd-001',
        namaIbadah: 'Sholat Dhuha',
      );

      expect(ibadah.id, 'ibd-001');
      expect(ibadah.namaIbadah, 'Sholat Dhuha');
      expect(ibadah.isDefault, isFalse);
    });
  });

  group('Baseline Theme Tests', () {
    test('AppTheme light and dark brightness verify', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(AppTheme.lightTheme.primaryColor, AppTheme.primaryLight);
      expect(AppTheme.darkTheme.primaryColor, AppTheme.primaryDark);
    });
  });

  group('Baseline Widget Tests', () {
    testWidgets('ReasonBadge renders reason chips and handles selection',
        (WidgetTester tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReasonBadge(
              selectedReason: 'Lupa',
              onSelected: (reason) {
                selected = reason;
              },
            ),
          ),
        ),
      );

      expect(find.text('Lupa'), findsOneWidget);
      expect(find.text('Ketiduran'), findsOneWidget);
      expect(find.text('Sibuk Kerja'), findsOneWidget);
      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);

      await tester.tap(find.text('Ketiduran'));
      await tester.pump();

      expect(selected, 'Ketiduran');
    });
  });
}
