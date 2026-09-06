import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';

enum CouponPrintFormat {
  businessCard('Biglietto da Visita (85x55 mm)', 'Standard copisteria (Pixartprinting, Vistaprint, ecc.)', 85, 55),
  flyerA6('Flyer A6 (105x148 mm)', 'Ideale da banco reception ed espositori partner', 105, 148),
  a4Grid('Foglio A4 a griglia (6 coupon)', 'Ideale per stampa immediata in ufficio con linee di ritaglio', 210, 297);

  final String label;
  final String description;
  final double widthMm;
  final double heightMm;
  const CouponPrintFormat(this.label, this.description, this.widthMm, this.heightMm);
}

class PromotionPdfService {
  /// Resolves an image from base64 data URL or HTTP URL
  static Future<pw.ImageProvider?> _resolveImage(String? urlOrData) async {
    if (urlOrData == null || urlOrData.trim().isEmpty) return null;
    final trimmed = urlOrData.trim();
    try {
      if (trimmed.startsWith('data:image')) {
        final commaIdx = trimmed.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(trimmed.substring(commaIdx + 1));
          return pw.MemoryImage(bytes);
        }
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return await networkImage(trimmed);
      }
    } catch (_) {}
    return null;
  }

  /// Builds header logos: internal promotion shows ONLY venue logo/name;
  /// partnership promotion shows both venue and partner logos side-by-side.
  static pw.Widget _buildHeaderLogos({
    required pw.ImageProvider? orgLogoImage,
    required pw.ImageProvider? partnerLogoImage,
    required String orgName,
    required PromotionModel promotion,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
    double logoHeight = 16,
    pw.MainAxisAlignment alignment = pw.MainAxisAlignment.start,
  }) {
    if (!promotion.isPartnership) {
      // Pure internal venue promotion: ONLY venue branding
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: alignment,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (orgLogoImage != null) ...[
            pw.Container(
              height: logoHeight,
              child: pw.Image(orgLogoImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 5),
          ],
          pw.Text(
            orgName.toUpperCase(),
            style: pw.TextStyle(font: fontBold, fontSize: logoHeight * 0.46, color: PdfColors.indigo900),
            maxLines: 1,
          ),
        ],
      );
    }

    // Partnership collaboration: display both logos / names
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (orgLogoImage != null)
          pw.Container(
            height: logoHeight,
            child: pw.Image(orgLogoImage, fit: pw.BoxFit.contain),
          )
        else
          pw.Text(
            orgName.toUpperCase(),
            style: pw.TextStyle(font: fontBold, fontSize: logoHeight * 0.42, color: PdfColors.indigo900),
            maxLines: 1,
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: pw.Text('✕', style: pw.TextStyle(font: fontBold, fontSize: logoHeight * 0.38, color: PdfColors.grey500)),
        ),
        if (partnerLogoImage != null)
          pw.Container(
            height: logoHeight,
            child: pw.Image(partnerLogoImage, fit: pw.BoxFit.contain),
          )
        else if (promotion.partnerName != null)
          pw.Text(
            promotion.partnerName!,
            style: pw.TextStyle(font: fontSemiBold, fontSize: logoHeight * 0.42, color: PdfColors.grey800),
            maxLines: 1,
          ),
      ],
    );
  }

  /// Main entrypoint: generates PDF based on the chosen format.
  static Future<Uint8List> generateDocument({
    required PromotionModel promotion,
    required List<VoucherModel> vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    required CouponPrintFormat format,
    String? baseUrl,
  }) async {
    switch (format) {
      case CouponPrintFormat.businessCard:
        return generateBusinessCards(
          promotion: promotion,
          vouchers: vouchers,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
        );
      case CouponPrintFormat.flyerA6:
        return generateFlyersA6(
          promotion: promotion,
          vouchers: vouchers,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
        );
      case CouponPrintFormat.a4Grid:
        return generateCouponSheet(
          promotion: promotion,
          vouchers: vouchers,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
        );
    }
  }

  /// 1. Standard European Business Card format (85 x 55 mm)
  /// Ready for online print shops (Pixartprinting, Vistaprint, Flyeralarm, Moo).
  static Future<Uint8List> generateBusinessCards({
    required PromotionModel promotion,
    required List<VoucherModel> vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    final cardFormat = PdfPageFormat(
      85 * PdfPageFormat.mm,
      55 * PdfPageFormat.mm,
      marginAll: 3.5 * PdfPageFormat.mm,
    );

    for (final voucher in vouchers) {
      final claimUrl = '$origin/p/${voucher.code}';

      pdf.addPage(
        pw.Page(
          pageFormat: cardFormat,
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Org & Partner
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: _buildHeaderLogos(
                          orgLogoImage: orgLogoImage,
                          partnerLogoImage: partnerLogoImage,
                          orgName: orgName,
                          promotion: promotion,
                          fontBold: fontBold,
                          fontSemiBold: fontSemiBold,
                          logoHeight: 14,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          promotion.offerType.label,
                          style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.indigo700),
                        ),
                      ),
                    ],
                  ),

                  pw.Divider(color: PdfColors.grey200, height: 6),

                  // Middle Row: Title & QR
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              promotion.title,
                              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black),
                              maxLines: 2,
                            ),
                            if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                promotion.description!,
                                style: pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey600),
                                maxLines: 2,
                              ),
                            ],
                            pw.SizedBox(height: 4),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(3),
                                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                              ),
                              child: pw.Text(
                                'CODICE: ${voucher.code}',
                                style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.blueGrey900, letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: claimUrl,
                            width: 38,
                            height: 38,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Inquadra QR',
                            style: pw.TextStyle(font: fontRegular, fontSize: 5, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.Divider(color: PdfColors.grey200, height: 6),

                  // Bottom Row: Expiration & Terms
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        expDateStr != null
                            ? 'Valido ${promotion.validityDays} gg da registrazione • Entro $expDateStr'
                            : 'Valido ${promotion.validityDays} gg da registrazione',
                        style: pw.TextStyle(font: fontSemiBold, fontSize: 5.5, color: PdfColors.red800),
                      ),
                      pw.Text(
                        promotion.paymentMethod == PromotionPaymentMethod.atVenue ? 'Paga in struttura' : 'Offerta attiva',
                        style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'ticketto.it',
                        style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: PdfColors.grey400),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// 2. Flyer A6 Format (105 x 148 mm)
  /// Ideal for partner counter displays, concierge desks, reception stands.
  static Future<Uint8List> generateFlyersA6({
    required PromotionModel promotion,
    required List<VoucherModel> vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    for (final voucher in vouchers) {
      final claimUrl = '$origin/p/${voucher.code}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6,
          margin: const pw.EdgeInsets.all(12),
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Header with logos
                  _buildHeaderLogos(
                    orgLogoImage: orgLogoImage,
                    partnerLogoImage: partnerLogoImage,
                    orgName: orgName,
                    promotion: promotion,
                    fontBold: fontBold,
                    fontSemiBold: fontSemiBold,
                    logoHeight: 22,
                    alignment: pw.MainAxisAlignment.center,
                  ),

                  pw.Divider(color: PdfColors.grey200, height: 10),

                  // Offer Type Badge
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
                    ),
                    child: pw.Text(
                      promotion.offerType.label,
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.indigo800),
                    ),
                  ),

                  // Promo Title
                  pw.Text(
                    promotion.title,
                    style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.black),
                    textAlign: pw.TextAlign.center,
                  ),

                  if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                    pw.Text(
                      promotion.description!,
                      style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center,
                      maxLines: 3,
                    ),
                  ],

                  // Big Center QR Code
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey200),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: claimUrl,
                      width: 72,
                      height: 72,
                      color: PdfColors.black,
                    ),
                  ),

                  // Prominent Code
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo900,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'CODICE: ${voucher.code}',
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white, letterSpacing: 1),
                    ),
                  ),

                  // Steps instructions
                  pw.Text(
                    '1. Inquadra il QR con la fotocamera\n2. Attiva la tua offerta inserendo i tuoi dati\n3. Mostra questo voucher al check-in',
                    style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.center,
                  ),

                  pw.Divider(color: PdfColors.grey200, height: 8),

                  // Footer
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        expDateStr != null
                            ? 'Valido ${promotion.validityDays} giorni da registrazione • Attiva entro $expDateStr'
                            : 'Valido ${promotion.validityDays} giorni dalla registrazione',
                        style: pw.TextStyle(font: fontSemiBold, fontSize: 7, color: PdfColors.red800),
                      ),
                      pw.Text(
                        promotion.paymentMethod == PromotionPaymentMethod.atVenue ? 'Pagamento alla reception' : 'Offerta digitale',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'ticketto.it',
                        style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey400),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// 3. A4 Printable Sheet (6 coupons per A4 page with dashed cut lines)
  /// For immediate office/reception printing.
  static Future<Uint8List> generateCouponSheet({
    required PromotionModel promotion,
    required List<VoucherModel> vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    const itemsPerPage = 6; // 2 cols x 3 rows

    for (var i = 0; i < vouchers.length; i += itemsPerPage) {
      final chunk = vouchers.skip(i).take(itemsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 1.45,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: chunk.map((voucher) {
                final claimUrl = '$origin/p/${voucher.code}';
                return _buildA4CouponCard(
                  promotion: promotion,
                  voucher: voucher,
                  orgName: orgName,
                  orgLogoImage: orgLogoImage,
                  partnerLogoImage: partnerLogoImage,
                  claimUrl: claimUrl,
                  expDateStr: expDateStr,
                  fontRegular: fontRegular,
                  fontBold: fontBold,
                  fontSemiBold: fontSemiBold,
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildA4CouponCard({
    required PromotionModel promotion,
    required VoucherModel voucher,
    required String orgName,
    required pw.ImageProvider? orgLogoImage,
    required pw.ImageProvider? partnerLogoImage,
    required String claimUrl,
    required String? expDateStr,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 1,
          style: pw.BorderStyle.dashed,
        ),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildHeaderLogos(
                  orgLogoImage: orgLogoImage,
                  partnerLogoImage: partnerLogoImage,
                  orgName: orgName,
                  promotion: promotion,
                  fontBold: fontBold,
                  fontSemiBold: fontSemiBold,
                  logoHeight: 18,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
                ),
                child: pw.Text(
                  promotion.offerType.label,
                  style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.indigo700),
                ),
              ),
            ],
          ),

          pw.Divider(color: PdfColors.grey200, height: 8),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      promotion.title,
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
                      maxLines: 2,
                    ),
                    if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        promotion.description!,
                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600),
                        maxLines: 2,
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo900,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'CODICE: ${voucher.code}',
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.white, letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: claimUrl,
                    width: 54,
                    height: 54,
                    color: PdfColors.black,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Scansiona per attivare',
                    style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),

          pw.Divider(color: PdfColors.grey200, height: 8),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                expDateStr != null
                    ? 'Valido ${promotion.validityDays} gg da registrazione • Attiva entro $expDateStr'
                    : 'Valido ${promotion.validityDays} gg da registrazione',
                style: pw.TextStyle(font: fontSemiBold, fontSize: 7, color: PdfColors.red800),
              ),
              pw.Text(
                promotion.paymentMethod == PromotionPaymentMethod.atVenue ? 'Pagamento in struttura' : 'Pagamento online',
                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'ticketto.it',
                style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.grey400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Triggers standard printing dialog / PDF download
  static Future<void> printCoupons({
    required PromotionModel promotion,
    required List<VoucherModel> vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    CouponPrintFormat format = CouponPrintFormat.a4Grid,
    String? baseUrl,
  }) async {
    final pdfBytes = await generateDocument(
      promotion: promotion,
      vouchers: vouchers,
      orgName: orgName,
      orgLogo: orgLogo,
      partnerLogo: partnerLogo,
      format: format,
      baseUrl: baseUrl,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdfBytes,
      name: 'Coupon_${promotion.codePrefix}_${format.name}.pdf',
    );
  }
}
