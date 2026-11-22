import 'package:flutter_test/flutter_test.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/promotions/data/voucher_duplicates.dart';

VoucherModel _voucher({
  String code = 'FITUP-0001',
  VoucherStatus status = VoucherStatus.claimed,
  String? nome = 'Sara',
  String? cognome = 'Rossi',
  String? email = 'sara.rossi@gmail.com',
  String? telefono,
}) =>
    VoucherModel(
      id: 'org_$code',
      promoId: 'promo',
      orgId: 'org',
      code: code,
      sequenceNumber: 1,
      status: status,
      claimedFirstName: nome,
      claimedLastName: cognome,
      claimedEmail: email,
      claimedPhone: telefono,
    );

void main() {
  group('trovaDoppione', () {
    test('caso FitUP: email con un refuso ma stesso telefono, preso dal telefono', () {
      final d = trovaDoppione(
        esistenti: [_voucher(telefono: '333 1234567')],
        email: 'sara.rossi@gnail.com',
        telefono: '+393331234567',
      );
      expect(d!.motivo, MotivoDoppione.telefono);
    });

    test('omonimi: stesso nome, email e telefono diversi, NON e un doppione', () {
      final d = trovaDoppione(
        esistenti: [_voucher(telefono: '3331234567')],
        email: 'altra.sara.rossi@libero.it',
        telefono: '3479999999',
      );
      expect(d, isNull);
    });

    test('stessa email con maiuscole e spazi', () {
      final d = trovaDoppione(
        esistenti: [_voucher()],
        email: '  Sara.Rossi@Gmail.com ',
      );
      expect(d!.motivo, MotivoDoppione.email);
    });

    test('stesso telefono scritto in modi diversi', () {
      final d = trovaDoppione(
        esistenti: [_voucher(email: 'a@b.it', telefono: '+39 333 123 4567')],
        email: 'c@d.it',
        telefono: '3331234567',
      );
      expect(d!.motivo, MotivoDoppione.telefono);
    });

    test('i voucher annullati o ancora disponibili non contano', () {
      final d = trovaDoppione(
        esistenti: [
          _voucher(status: VoucherStatus.cancelled),
          _voucher(status: VoucherStatus.available),
        ],
        email: 'sara.rossi@gmail.com',
      );
      expect(d, isNull);
    });

    test('persona diversa: nessun doppione', () {
      final d = trovaDoppione(
        esistenti: [_voucher()],
        email: 'marco@gmail.com',
        telefono: '3470000000',
      );
      expect(d, isNull);
    });

    test('il voucher gia usato conta come doppione', () {
      final d = trovaDoppione(
        esistenti: [_voucher(status: VoucherStatus.redeemed)],
        email: 'sara.rossi@gmail.com',
      );
      expect(d, isNotNull);
    });
  });

  group('normalizzazioni', () {
    test('telefono senza prefisso e senza simboli', () {
      expect(normalizzaTelefono('+39 333-123.4567'), '3331234567');
      expect(normalizzaTelefono('0039 3331234567'), '3331234567');
      expect(normalizzaTelefono(null), '');
    });
  });

  group('stessoNomeNellaCampagna (avviso in reception)', () {
    test('caso FitUP: trova l altro voucher con lo stesso nome scritto diverso', () {
      final daConvalidare = _voucher(code: 'FITUP-0001', nome: 'sara', cognome: 'ROSSI ');
      final altro = _voucher(code: 'FITUP-0002', status: VoucherStatus.redeemed, email: 'sara.rossi@gnail.com');
      final r = stessoNomeNellaCampagna(daConvalidare, [daConvalidare, altro]);
      expect(r.map((v) => v.code), ['FITUP-0002']);
    });

    test('non conta se stesso, gli annullati e i nomi diversi', () {
      final daConvalidare = _voucher(code: 'A');
      final r = stessoNomeNellaCampagna(daConvalidare, [
        daConvalidare,
        _voucher(code: 'B', status: VoucherStatus.cancelled),
        _voucher(code: 'C', nome: 'Marco'),
      ]);
      expect(r, isEmpty);
    });

    test('accenti e apostrofi non contano', () {
      final a = _voucher(code: 'A', nome: 'Niccolò', cognome: "D'Angelo");
      final b = _voucher(code: 'B', nome: 'niccolo', cognome: 'dangelo');
      expect(stessoNomeNellaCampagna(a, [a, b]).length, 1);
    });
  });
}
