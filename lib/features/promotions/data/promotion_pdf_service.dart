import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/models.dart';

enum CouponPrintFormat {
  deskStandA4('Locandina da Banco A4 (210x297 mm)', 'Cartello verticale con grande QR code per desk ed espositori in plexiglass', 210, 297),
  businessCard('Biglietto da Visita (85x55 mm)', 'File master per tipografia (Pixartprinting, Vistaprint, ecc.) con QR unico', 85, 55),
  flyerA6('Flyer A6 (105x148 mm)', 'Ideale da banco reception ed espositori partner', 105, 148),
  a4Grid('Foglio A4 a griglia (6 coupon)', 'Ideale per stampa immediata in ufficio con linee di ritaglio tratteggiate', 210, 297);

  final String label;
  final String description;
  final double widthMm;
  final double heightMm;
  const CouponPrintFormat(this.label, this.description, this.widthMm, this.heightMm);
}

enum CouponVisualTheme {
  luxurySpa(
    'Luxury SPA & Wellness',
    'Sfondo scuro blu ardesia, accenti oro caldo e finiture di pregio. Ideale per SPA, hotel e wellness club.',
  ),
  sportDynamic(
    'Sport & Dynamic Energy',
    'Contrasti netti nero grafite e accento verde lime fluo. Ideale per palestre, fitness e centri sportivi.',
  ),
  modernMinimal(
    'Clean Modern Ticket',
    'Finitura bianca moderna con accenti indaco e stile voucher regalo.',
  );

  final String label;
  final String description;
  const CouponVisualTheme(this.label, this.description);
}

class _ThemePalette {
  final PdfColor primaryBg;
  final PdfColor qrSectionBg;
  final PdfColor textPrimary;
  final PdfColor textSecondary;
  final PdfColor accentColor;
  final PdfColor accentText;
  final PdfColor borderColor;
  final PdfColor dividerColor;
  final PdfColor badgeBg;
  final PdfColor badgeText;
  final PdfColor codeBg;
  final PdfColor codeText;

  const _ThemePalette({
    required this.primaryBg,
    required this.qrSectionBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentColor,
    required this.accentText,
    required this.borderColor,
    required this.dividerColor,
    required this.badgeBg,
    required this.badgeText,
    required this.codeBg,
    required this.codeText,
  });

  factory _ThemePalette.fromTheme(CouponVisualTheme theme) {
    switch (theme) {
      case CouponVisualTheme.luxurySpa:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('0F172A'),     // Dark slate navy
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('94A3B8'), // Slate-400
          accentColor: PdfColor.fromHex('D97706'),   // Warm Amber/Gold
          accentText: PdfColors.white,
          borderColor: PdfColor.fromHex('334155'),   // Slate-700
          dividerColor: PdfColor.fromHex('CBD5E1'),  // Slate-300
          badgeBg: PdfColor.fromHex('1E293B'),       // Slate-800
          badgeText: PdfColor.fromHex('FCD34D'),     // Amber-300
          codeBg: PdfColor.fromHex('D97706'),        // Amber-600 gold
          codeText: PdfColors.white,
        );
      case CouponVisualTheme.sportDynamic:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('09090B'),     // Graphite black
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('A1A1AA'), // Cool grey
          accentColor: PdfColor.fromHex('84CC16'),   // Lime Green
          accentText: PdfColor.fromHex('09090B'),    // Dark on lime
          borderColor: PdfColor.fromHex('27272A'),   // Dark grey
          dividerColor: PdfColor.fromHex('E4E4E7'),
          badgeBg: PdfColor.fromHex('18181B'),
          badgeText: PdfColor.fromHex('A3E635'),     // Bright lime
          codeBg: PdfColor.fromHex('84CC16'),        // Lime
          codeText: PdfColor.fromHex('09090B'),
        );
      case CouponVisualTheme.modernMinimal:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('F8FAFC'),     // Clean slate-50
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColor.fromHex('0F172A'),   // Dark slate-900
          textSecondary: PdfColor.fromHex('64748B'), // Slate-500
          accentColor: PdfColor.fromHex('4338CA'),   // Indigo-700
          accentText: PdfColors.white,
          borderColor: PdfColor.fromHex('CBD5E1'),   // Slate-300
          dividerColor: PdfColor.fromHex('E2E8F0'),
          badgeBg: PdfColor.fromHex('EEF2FF'),       // Indigo-50
          badgeText: PdfColor.fromHex('4338CA'),     // Indigo-700
          codeBg: PdfColor.fromHex('4338CA'),        // Indigo-700
          codeText: PdfColors.white,
        );
    }
  }
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
    bool? overridePartnerLogoDarkBg,
    PdfColor? textLightColor,
  }) {
    final titleColor = textLightColor ?? PdfColors.indigo900;
    final partnerColor = textLightColor ?? PdfColors.grey800;
    final xColor = textLightColor != null ? PdfColor.fromHex('94A3B8') : PdfColors.grey500;

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
            style: pw.TextStyle(font: fontBold, fontSize: logoHeight * 0.46, color: titleColor),
            maxLines: 1,
          ),
        ],
      );
    }

    final effectiveDarkBg = overridePartnerLogoDarkBg ?? promotion.partnerLogoDarkBg;

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
            style: pw.TextStyle(font: fontBold, fontSize: logoHeight * 0.42, color: titleColor),
            maxLines: 1,
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5),
          child: pw.Text('x', style: pw.TextStyle(font: fontBold, fontSize: logoHeight * 0.36, color: xColor)),
        ),
        if (partnerLogoImage != null)
          if (effectiveDarkBg)
            pw.Container(
              height: logoHeight,
              padding: pw.EdgeInsets.symmetric(
                horizontal: logoHeight > 20 ? 8 : (logoHeight > 14 ? 5 : 3.5),
                vertical: logoHeight > 20 ? 4 : (logoHeight > 14 ? 2.5 : 1.5),
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('0F172A'),
                borderRadius: pw.BorderRadius.circular(logoHeight > 20 ? 6 : 3),
              ),
              child: pw.Image(partnerLogoImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              height: logoHeight,
              child: pw.Image(partnerLogoImage, fit: pw.BoxFit.contain),
            )
        else if (promotion.partnerName != null)
          pw.Text(
            promotion.partnerName!,
            style: pw.TextStyle(font: fontSemiBold, fontSize: logoHeight * 0.42, color: partnerColor),
            maxLines: 1,
          ),
      ],
    );
  }

  /// Main entrypoint: generates PDF based on the chosen format and visual theme.
  static Future<Uint8List> generateDocument({
    required PromotionModel promotion,
    required List<VoucherModel> vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    required CouponPrintFormat format,
    String? baseUrl,
    bool? overridePartnerLogoDarkBg,
    CouponVisualTheme theme = CouponVisualTheme.luxurySpa,
  }) async {
    switch (format) {
      case CouponPrintFormat.deskStandA4:
        return generateDeskStandPoster(
          promotion: promotion,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
          theme: theme,
        );
      case CouponPrintFormat.businessCard:
        return generateBusinessCards(
          promotion: promotion,
          vouchers: vouchers,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
          theme: theme,
        );
      case CouponPrintFormat.flyerA6:
        return generateFlyersA6(
          promotion: promotion,
          vouchers: vouchers,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
          theme: theme,
        );
      case CouponPrintFormat.a4Grid:
        return generateCouponSheet(
          promotion: promotion,
          vouchers: vouchers,
          orgName: orgName,
          orgLogo: orgLogo,
          partnerLogo: partnerLogo,
          baseUrl: baseUrl,
          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
          theme: theme,
        );
    }
  }

  /// 1. Locandina da Banco A4 (210 x 297 mm)
  /// Ideale per leggio, espositore in plexiglass da banco reception o parete partner.
  static Future<Uint8List> generateDeskStandPoster({
    required PromotionModel promotion,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
    bool? overridePartnerLogoDarkBg,
    CouponVisualTheme theme = CouponVisualTheme.luxurySpa,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme != CouponVisualTheme.modernMinimal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: palette.primaryBg, width: 2),
            ),
            child: pw.Column(
              children: [
                // Top Header Banner with Theme Background
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: pw.BoxDecoration(
                    color: palette.primaryBg,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(14),
                      topRight: pw.Radius.circular(14),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildHeaderLogos(
                        orgLogoImage: orgLogoImage,
                        partnerLogoImage: partnerLogoImage,
                        orgName: orgName,
                        promotion: promotion,
                        fontBold: fontBold,
                        fontSemiBold: fontSemiBold,
                        logoHeight: 34,
                        alignment: pw.MainAxisAlignment.center,
                        overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                        textLightColor: isDark ? PdfColors.white : null,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        height: 2,
                        width: 80,
                        color: palette.accentColor,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty
                            ? 'CONVENZIONE ESCLUSIVA RISERVATA AI SOCI ${promotion.partnerName!.toUpperCase()}'
                            : 'PROMOZIONE ESCLUSIVA',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: isDark ? palette.accentColor : PdfColors.indigo700,
                          letterSpacing: 1.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Main Body (Clean Canvas)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Promo Title & Offer Badge
                        pw.Column(
                          children: [
                            pw.Text(
                              promotion.title,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 24,
                                color: palette.primaryBg,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: palette.badgeBg,
                                borderRadius: pw.BorderRadius.circular(20),
                                border: pw.Border.all(color: palette.accentColor, width: 1),
                              ),
                              child: pw.Text(
                                promotion.offerType.label.toUpperCase(),
                                style: pw.TextStyle(font: fontBold, fontSize: 12, color: palette.badgeText, letterSpacing: 0.8),
                              ),
                            ),
                            if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                              pw.SizedBox(height: 8),
                              pw.ConstrainedBox(
                                constraints: const pw.BoxConstraints(maxWidth: 420),
                                child: pw.Text(
                                  promotion.description!,
                                  style: pw.TextStyle(font: fontRegular, fontSize: 10.5, color: PdfColors.grey700),
                                  textAlign: pw.TextAlign.center,
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Center QR Box with High-Contrast Frame
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            borderRadius: pw.BorderRadius.circular(16),
                            border: pw.Border.all(color: palette.accentColor, width: 1.5),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'ATTIVA IL TUO PASS DIGITALE',
                                style: pw.TextStyle(font: fontBold, fontSize: 12, color: palette.primaryBg, letterSpacing: 1),
                              ),
                              pw.SizedBox(height: 10),
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: claimUrl,
                                width: 90,
                                height: 90,
                                color: PdfColors.black,
                              ),
                              pw.SizedBox(height: 10),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: palette.codeBg,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text(
                                  'CODICE DI CAMPAGNA: ${promotion.codePrefix}',
                                  style: pw.TextStyle(font: fontBold, fontSize: 11, color: palette.codeText, letterSpacing: 1),
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Inquadra il QR con la fotocamera dello smartphone',
                                style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey600),
                              ),
                            ],
                          ),
                        ),

                        // 3 Quick Steps
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStepItem('1. INQUADRA', 'Apri la fotocamera del tuo smartphone', fontBold, fontRegular, palette),
                            _buildStepItem('2. REGISTRATI', 'Inserisci i tuoi dati in 10 secondi', fontBold, fontRegular, palette),
                            _buildStepItem('3. MOSTRA', 'Presenta il Pass Digitale al desk', fontBold, fontRegular, palette),
                          ],
                        ),

                        // Footer Terms & Expiry
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '• Validità pass: ${promotion.validityDays} giorni dalla data di attivazione',
                                style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: PdfColors.grey800),
                              ),
                              if (expDateStr != null)
                                pw.Text(
                                  '• Registrazioni aperte fino al $expDateStr',
                                  style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.red800),
                                ),
                              pw.Text(
                                'ticketto.it',
                                style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.grey500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStepItem(
    String title,
    String desc,
    pw.Font fontBold,
    pw.Font fontRegular,
    _ThemePalette palette,
  ) {
    return pw.Container(
      width: 140,
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: palette.primaryBg)),
          pw.SizedBox(height: 2),
          pw.Text(
            desc,
            style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Reusable Split-Card Widget with ticket notch and high-contrast QR section.
  /// Used for standard business card (85x55mm) and for A4 grid sheets.
  static pw.Widget _buildSplitBusinessCard({
    required PromotionModel promotion,
    required String orgName,
    required pw.ImageProvider? orgLogoImage,
    required pw.ImageProvider? partnerLogoImage,
    required String claimUrl,
    required String? expDateStr,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
    required CouponVisualTheme theme,
    bool? overridePartnerLogoDarkBg,
    bool isGridItem = false,
  }) {
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme != CouponVisualTheme.modernMinimal;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: palette.primaryBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: isGridItem ? PdfColors.grey400 : palette.borderColor,
          width: 0.75,
          style: isGridItem ? pw.BorderStyle.dashed : pw.BorderStyle.solid,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Left section (Brand & Offer)
          pw.Expanded(
            flex: 60,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeaderLogos(
                    orgLogoImage: orgLogoImage,
                    partnerLogoImage: partnerLogoImage,
                    orgName: orgName,
                    promotion: promotion,
                    fontBold: fontBold,
                    fontSemiBold: fontSemiBold,
                    logoHeight: 13,
                    overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                    textLightColor: isDark ? PdfColors.white : null,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: palette.badgeBg,
                      borderRadius: pw.BorderRadius.circular(3),
                      border: pw.Border.all(color: palette.accentColor, width: 0.5),
                    ),
                    child: pw.Text(
                      promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty
                          ? 'CONVENZIONE ${promotion.partnerName!.toUpperCase()}'
                          : promotion.offerType.label.toUpperCase(),
                      style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: palette.badgeText, letterSpacing: 0.3),
                      maxLines: 1,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    promotion.title,
                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: palette.textPrimary),
                    maxLines: 2,
                  ),
                  if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 1),
                    pw.Text(
                      promotion.description!,
                      style: pw.TextStyle(font: fontRegular, fontSize: 5, color: palette.textSecondary),
                      maxLines: 1,
                    ),
                  ],
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: palette.codeBg,
                          borderRadius: pw.BorderRadius.circular(2.5),
                        ),
                        child: pw.Text(
                          'CODICE: ${promotion.codePrefix}',
                          style: pw.TextStyle(font: fontBold, fontSize: 7, color: palette.codeText, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Valido ${promotion.validityDays} gg da attivazione',
                    style: pw.TextStyle(font: fontRegular, fontSize: 4.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Center Ticket Notch & Perforation
          pw.Container(
            width: 8,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  width: 8,
                  height: 4,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(4),
                      bottomRight: pw.Radius.circular(4),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Container(
                      width: 0.75,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: PdfColors.grey300, width: 0.75, style: pw.BorderStyle.dashed),
                        ),
                      ),
                    ),
                  ),
                ),
                pw.Container(
                  width: 8,
                  height: 4,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(4),
                      topRight: pw.Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right section (Pure White QR & Activation)
          pw.Expanded(
            flex: 40,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.only(
                  topRight: pw.Radius.circular(5),
                  bottomRight: pw.Radius.circular(5),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'ATTIVA IL TUO PASS',
                    style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: PdfColors.indigo900, letterSpacing: 0.4),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: claimUrl,
                    width: 27,
                    height: 27,
                    color: PdfColors.black,
                  ),
                  pw.Text(
                    'Inquadra con fotocamera',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 4.5, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    expDateStr != null ? 'Attiva entro $expDateStr' : 'ticketto.it',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 4,
                      color: expDateStr != null ? PdfColors.red800 : PdfColors.grey500,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Standard European Business Card format (85 x 55 mm)
  /// Ready for online print shops (Pixartprinting, Vistaprint, Flyeralarm, Moo).
  /// Contiene il QR Code unico di campagna: tutti i biglietti stampati sono identici.
  static Future<Uint8List> generateBusinessCards({
    required PromotionModel promotion,
    List<VoucherModel>? vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
    bool? overridePartnerLogoDarkBg,
    CouponVisualTheme theme = CouponVisualTheme.luxurySpa,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    final cardFormat = PdfPageFormat(
      85 * PdfPageFormat.mm,
      55 * PdfPageFormat.mm,
      marginAll: 2.5 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: cardFormat,
        build: (context) {
          return _buildSplitBusinessCard(
            promotion: promotion,
            orgName: orgName,
            orgLogoImage: orgLogoImage,
            partnerLogoImage: partnerLogoImage,
            claimUrl: claimUrl,
            expDateStr: expDateStr,
            fontRegular: fontRegular,
            fontBold: fontBold,
            fontSemiBold: fontSemiBold,
            theme: theme,
            overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
            isGridItem: false,
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 3. Flyer A6 Format (105 x 148 mm)
  /// Ideale per desk reception, bancone ed espositori partner.
  /// Contiene il QR Code unico di campagna: tutte le copie stampate sono identiche.
  static Future<Uint8List> generateFlyersA6({
    required PromotionModel promotion,
    List<VoucherModel>? vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
    bool? overridePartnerLogoDarkBg,
    CouponVisualTheme theme = CouponVisualTheme.luxurySpa,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme != CouponVisualTheme.modernMinimal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(10),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: palette.primaryBg, width: 1.5),
            ),
            child: pw.Column(
              children: [
                // Top Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: palette.primaryBg,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8.5),
                      topRight: pw.Radius.circular(8.5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildHeaderLogos(
                        orgLogoImage: orgLogoImage,
                        partnerLogoImage: partnerLogoImage,
                        orgName: orgName,
                        promotion: promotion,
                        fontBold: fontBold,
                        fontSemiBold: fontSemiBold,
                        logoHeight: 20,
                        alignment: pw.MainAxisAlignment.center,
                        overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                        textLightColor: isDark ? PdfColors.white : null,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(height: 1.5, width: 50, color: palette.accentColor),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty
                            ? 'CONVENZIONE ESCLUSIVA SOCI ${promotion.partnerName!.toUpperCase()}'
                            : 'PROMOZIONE ESCLUSIVA',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 6.5,
                          color: isDark ? palette.accentColor : PdfColors.indigo700,
                          letterSpacing: 1,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Main Flyer Body
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Promo Title & Badge
                        pw.Column(
                          children: [
                            pw.Text(
                              promotion.title,
                              style: pw.TextStyle(font: fontBold, fontSize: 13, color: palette.primaryBg),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: palette.badgeBg,
                                borderRadius: pw.BorderRadius.circular(10),
                                border: pw.Border.all(color: palette.accentColor, width: 0.5),
                              ),
                              child: pw.Text(
                                promotion.offerType.label.toUpperCase(),
                                style: pw.TextStyle(font: fontBold, fontSize: 8, color: palette.badgeText),
                              ),
                            ),
                            if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              pw.Text(
                                promotion.description!,
                                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey700),
                                textAlign: pw.TextAlign.center,
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),

                        // Center QR Card
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            borderRadius: pw.BorderRadius.circular(10),
                            border: pw.Border.all(color: palette.accentColor, width: 1),
                          ),
                          child: pw.Column(
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: claimUrl,
                                width: 56,
                                height: 56,
                                color: PdfColors.black,
                              ),
                              pw.SizedBox(height: 5),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: palette.codeBg,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(
                                  'CODICE: ${promotion.codePrefix}',
                                  style: pw.TextStyle(font: fontBold, fontSize: 9, color: palette.codeText, letterSpacing: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Steps Instructions
                        pw.Text(
                          '1. Inquadra il QR con la fotocamera\n2. Attiva la tua offerta in pochi secondi\n3. Mostra il tuo Pass Digitale alla reception',
                          style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: PdfColors.grey600),
                          textAlign: pw.TextAlign.center,
                        ),

                        // Footer
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                expDateStr != null
                                    ? 'Valido ${promotion.validityDays} gg • Entro $expDateStr'
                                    : 'Valido ${promotion.validityDays} gg da attivazione',
                                style: pw.TextStyle(font: fontSemiBold, fontSize: 5.5, color: PdfColors.red800),
                              ),
                              pw.Text('ticketto.it', style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: PdfColors.grey500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 4. Foglio A4 a griglia (6 coupon identici con linee di ritaglio tratteggiate)
  /// Ideale per stampare comodamente con la stampante dell'ufficio.
  static Future<Uint8List> generateCouponSheet({
    required PromotionModel promotion,
    List<VoucherModel>? vouchers,
    required String orgName,
    String? orgLogo,
    String? partnerLogo,
    String? baseUrl,
    bool? overridePartnerLogoDarkBg,
    CouponVisualTheme theme = CouponVisualTheme.luxurySpa,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? 'https://eventflow-3541b.web.app';
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    const itemsPerPage = 6; // 2 cols x 3 rows

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        build: (context) {
          return pw.GridView(
            crossAxisCount: 2,
            childAspectRatio: 1.52,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            children: List.generate(itemsPerPage, (_) {
              return _buildSplitBusinessCard(
                promotion: promotion,
                orgName: orgName,
                orgLogoImage: orgLogoImage,
                partnerLogoImage: partnerLogoImage,
                claimUrl: claimUrl,
                expDateStr: expDateStr,
                fontRegular: fontRegular,
                fontBold: fontBold,
                fontSemiBold: fontSemiBold,
                theme: theme,
                overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                isGridItem: true,
              );
            }),
          );
        },
      ),
    );

    return pdf.save();
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
    bool? overridePartnerLogoDarkBg,
    CouponVisualTheme theme = CouponVisualTheme.luxurySpa,
  }) async {
    final pdfBytes = await generateDocument(
      promotion: promotion,
      vouchers: vouchers,
      orgName: orgName,
      orgLogo: orgLogo,
      partnerLogo: partnerLogo,
      format: format,
      baseUrl: baseUrl,
      overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
      theme: theme,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdfBytes,
      name: 'Coupon_${promotion.codePrefix}_${format.name}_${theme.name}.pdf',
    );
  }
}
