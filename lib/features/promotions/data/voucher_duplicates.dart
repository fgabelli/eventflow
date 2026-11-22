// Riconosce se chi compila il modulo di una campagna ha gia' un voucher.
//
// Nato il 22/11/2026: sulla campagna FitUP Lissone una cliente ha rifatto il
// modulo quattro giorni dopo, con l'email sbagliata di una lettera
// (gmail -> gnail) e senza telefono, e ha ricevuto un secondo codice.
//
// Si confrontano solo email e telefono, che identificano la persona.
// Il nome NO: esistono gli omonimi e bloccheremmo clienti vere (deciso da
// Fabio il 22/11/2026). Per questo nelle campagne il telefono e' diventato
// obbligatorio: e' quello che ferma chi sbaglia l'email.

import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';

/// Come e' stato riconosciuto il doppione.
enum MotivoDoppione { email, telefono }

class Doppione {
  final VoucherModel voucher;
  final MotivoDoppione motivo;
  const Doppione(this.voucher, this.motivo);
}

/// Minimo di cifre per considerare valido un cellulare.
const int cifreMinimeTelefono = 8;

String normalizzaEmail(String? s) => (s ?? '').trim().toLowerCase();

/// Solo cifre, senza prefisso internazionale italiano.
String normalizzaTelefono(String? s) {
  var cifre = (s ?? '').replaceAll(RegExp(r'\D'), '');
  if (cifre.startsWith('0039')) cifre = cifre.substring(4);
  if (cifre.startsWith('39') && cifre.length > 10) cifre = cifre.substring(2);
  return cifre;
}

/// Cerca tra i voucher gia' attivati o usati della campagna quello con la
/// stessa email o lo stesso telefono. I voucher annullati non contano.
Doppione? trovaDoppione({
  required Iterable<VoucherModel> esistenti,
  required String email,
  String? telefono,
}) {
  final attivi = esistenti
      .where((v) => v.status == VoucherStatus.claimed || v.status == VoucherStatus.redeemed)
      .toList();

  final e = normalizzaEmail(email);
  if (e.isNotEmpty) {
    for (final v in attivi) {
      if (normalizzaEmail(v.claimedEmail) == e) return Doppione(v, MotivoDoppione.email);
    }
  }

  final t = normalizzaTelefono(telefono);
  if (t.length >= cifreMinimeTelefono) {
    for (final v in attivi) {
      if (normalizzaTelefono(v.claimedPhone) == t) return Doppione(v, MotivoDoppione.telefono);
    }
  }
  return null;
}

// ---------------------------------------------------------------------
// In reception il nome SI usa, ma solo come avviso: chi chiede la convalida
// e' li' di persona, e se nella stessa campagna c'e' gia' un voucher con lo
// stesso nome e cognome lo staff chiede un documento. Non blocca nulla,
// cosi' gli omonimi non hanno problemi (serve a fermare chi si registra con
// email e telefoni diversi, deciso con Fabio il 22/11/2026).

const _accenti = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n',
};

/// Minuscolo, senza accenti, apostrofi o spazi doppi.
String normalizzaNome(String? s) {
  final base = (s ?? '').trim().toLowerCase();
  final senzaAccenti = base.split('').map((c) => _accenti[c] ?? c).join();
  return senzaAccenti
      .replaceAll(RegExp(r"[^a-z0-9 ]"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Gli altri voucher attivati o usati della stessa campagna intestati allo
/// stesso nome e cognome di [voucher]. Lista vuota se non ce ne sono.
List<VoucherModel> stessoNomeNellaCampagna(VoucherModel voucher, Iterable<VoucherModel> campagna) {
  final n = normalizzaNome('${voucher.claimedFirstName ?? ''} ${voucher.claimedLastName ?? ''}');
  if (!n.contains(' ')) return const [];
  return campagna
      .where((v) =>
          v.id != voucher.id &&
          v.promoId == voucher.promoId &&
          (v.status == VoucherStatus.claimed || v.status == VoucherStatus.redeemed) &&
          normalizzaNome('${v.claimedFirstName ?? ''} ${v.claimedLastName ?? ''}') == n)
      .toList();
}
