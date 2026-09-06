import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
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

  /// Safely loads an image from Flutter asset bundle, returning null on error or headless testing.
  static Future<pw.ImageProvider?> _loadAssetImage(String path) async {
    try {
      final byteData = await rootBundle.load(path);
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
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
        // Elegant Vertical Hairline Divider (Replaces 'x')
        pw.Container(
          width: 1.2,
          height: logoHeight * 0.75,
          margin: pw.EdgeInsets.symmetric(horizontal: logoHeight > 24 ? 10 : (logoHeight > 16 ? 6 : 4)),
          color: xColor,
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

    pw.ImageProvider? flyerBgImage;
    if (theme == CouponVisualTheme.luxurySpa) {
      flyerBgImage = await _loadAssetImage('assets/images/coupons/spa_bg.jpg');
    } else if (theme == CouponVisualTheme.sportDynamic) {
      flyerBgImage = await _loadAssetImage('assets/images/coupons/sport_bg.jpg');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: isDark ? palette.primaryBg : PdfColors.white,
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: palette.accentColor, width: 2),
            ),
            child: pw.Column(
              children: [
                // 1. TOP HERO: Photographic Visual Banner (AI generated photo!)
                if (flyerBgImage != null)
                  pw.Container(
                    height: 250,
                    width: double.infinity,
                    child: pw.ClipRRect(
                      horizontalRadius: 14,
                      verticalRadius: 14,
                      child: pw.Stack(
                        children: [
                          pw.Positioned.fill(
                            child: pw.Image(flyerBgImage, fit: pw.BoxFit.cover),
                          ),
                          // Floating translucent exclusivity badge
                          pw.Positioned(
                            top: 14,
                            right: 14,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: PdfColor(0.04, 0.05, 0.08, 0.75),
                                borderRadius: pw.BorderRadius.circular(20),
                                border: pw.Border.all(color: palette.accentColor, width: 1),
                              ),
                              child: pw.Text(
                                'PROMOZIONE ESCLUSIVA',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 8.5,
                                  color: palette.badgeText,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Minimal / Clean fallback header banner
                  pw.Container(
                    width: double.infinity,
                    height: 90,
                    decoration: pw.BoxDecoration(
                      color: palette.primaryBg,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(14)),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: pw.Center(
                      child: pw.Text(
                        'PROMOZIONE ESCLUSIVA',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          color: palette.badgeText,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),

                // 2. CO-BRANDING HEADER BAR (Devero SPA | FitUP Lissone - NO "x"!)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: isDark ? PdfColor.fromHex('0B1120') : PdfColor.fromHex('F8FAFC'),
                    border: pw.Border(
                      bottom: pw.BorderSide(color: palette.borderColor, width: 1),
                    ),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      _buildHeaderLogos(
                        orgLogoImage: orgLogoImage,
                        partnerLogoImage: partnerLogoImage,
                        orgName: orgName,
                        promotion: promotion,
                        fontBold: fontBold,
                        fontSemiBold: fontSemiBold,
                        logoHeight: 32,
                        alignment: pw.MainAxisAlignment.center,
                        overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                        textLightColor: isDark ? PdfColors.white : null,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty
                            ? 'CONVENZIONE ESCLUSIVA RISERVATA AI SOCI ${promotion.partnerName!.toUpperCase()}'
                            : 'PROMOZIONE UFFICIALE RISERVATA AI CLIENTI',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 9.5,
                          color: palette.badgeText,
                          letterSpacing: 1.2,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // 3. MAIN OFFER CONTENT & QR SECTION
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Offer Headline and Description
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              decoration: pw.BoxDecoration(
                                color: palette.badgeBg,
                                borderRadius: pw.BorderRadius.circular(20),
                                border: pw.Border.all(color: palette.accentColor, width: 1),
                              ),
                              child: pw.Text(
                                promotion.offerType.label.toUpperCase(),
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 11,
                                  color: palette.badgeText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text(
                              promotion.title,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 22,
                                color: isDark ? PdfColors.white : palette.primaryBg,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                              pw.SizedBox(height: 8),
                              pw.Container(
                                constraints: const pw.BoxConstraints(maxWidth: 460),
                                child: pw.Text(
                                  promotion.description!,
                                  style: pw.TextStyle(
                                    font: fontRegular,
                                    fontSize: 10.5,
                                    color: isDark ? PdfColor.fromHex('CBD5E1') : PdfColor.fromHex('475569'),
                                  ),
                                  textAlign: pw.TextAlign.center,
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Large Actionable QR Placard
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            color: isDark ? PdfColor.fromHex('1E293B') : PdfColor.fromHex('F8FAFC'),
                            borderRadius: pw.BorderRadius.circular(14),
                            border: pw.Border.all(color: palette.accentColor, width: 1.5),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              // White QR square with Accent Border
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(10),
                                  border: pw.Border.all(color: palette.accentColor, width: 1.2),
                                ),
                                child: pw.Column(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data: claimUrl,
                                      width: 90,
                                      height: 90,
                                      color: PdfColors.black,
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      'INQUADRA CON LO SMARTPHONE',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 6,
                                        color: PdfColors.grey800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(width: 18),
                              // Scan instructions & validity
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    pw.Text(
                                      'ATTIVA IL TUO PASS DIGITALE',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 13,
                                        color: isDark ? palette.accentColor : palette.primaryBg,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    pw.SizedBox(height: 5),
                                    pw.Text(
                                      'Punta la fotocamera del tuo smartphone sul codice QR per registrarti in pochi secondi e sbloccare la convenzione.',
                                      style: pw.TextStyle(
                                        font: fontRegular,
                                        fontSize: 9.5,
                                        color: isDark ? PdfColor.fromHex('CBD5E1') : PdfColor.fromHex('334155'),
                                      ),
                                    ),
                                    pw.SizedBox(height: 10),
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: pw.BoxDecoration(
                                        color: palette.badgeBg,
                                        borderRadius: pw.BorderRadius.circular(6),
                                        border: pw.Border.all(color: palette.borderColor, width: 0.8),
                                      ),
                                      child: pw.Text(
                                        expDateStr != null
                                            ? 'Attiva entro il $expDateStr • Valido ${promotion.validityDays} giorni'
                                            : 'Validità: ${promotion.validityDays} giorni dall\'attivazione',
                                        style: pw.TextStyle(
                                          font: fontSemiBold,
                                          fontSize: 8.5,
                                          color: palette.badgeText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4. FOOTER: 3 STEPS
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: isDark ? PdfColor.fromHex('0B1120') : PdfColor.fromHex('F1F5F9'),
                            borderRadius: pw.BorderRadius.circular(10),
                            border: pw.Border.all(color: palette.borderColor, width: 0.8),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                            children: [
                              _buildStepItem('1. INQUADRA', 'Apri la fotocamera dello smartphone', fontBold, fontRegular, palette, isDark: isDark),
                              _buildStepItem('2. REGISTRATI', 'Inserisci nome e email in 10 secondi', fontBold, fontRegular, palette, isDark: isDark),
                              _buildStepItem('3. CHECK-IN', 'Mostra il pass digitale alla reception', fontBold, fontRegular, palette, isDark: isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Brand Bar
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: isDark ? PdfColor.fromHex('060913') : PdfColor.fromHex('E2E8F0'),
                    borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(14)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Eventflow • Piattaforma Gestione Pass & Convenzioni',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: isDark ? PdfColor.fromHex('94A3B8') : PdfColor.fromHex('64748B')),
                      ),
                      pw.Text(
                        'eventflow.it',
                        style: pw.TextStyle(font: fontBold, fontSize: 7, color: palette.accentColor),
                      ),
                    ],
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
    _ThemePalette palette, {
    bool isDark = false,
  }) {
    return pw.Container(
      width: 140,
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: isDark ? PdfColors.white : palette.primaryBg)),
          pw.SizedBox(height: 2),
          pw.Text(
            desc,
            style: pw.TextStyle(font: fontRegular, fontSize: 7, color: isDark ? PdfColor.fromHex('CBD5E1') : PdfColors.grey600),
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
    pw.ImageProvider? ticketBgImage,
  }) {
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme != CouponVisualTheme.modernMinimal;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: palette.primaryBg,
        border: isGridItem
            ? pw.Border.all(color: PdfColors.grey400, width: 0.5, style: pw.BorderStyle.dashed)
            : null,
      ),
      child: pw.Stack(
        children: [
          // 1. Full-bleed background photo as subtle texture
          if (ticketBgImage != null)
            pw.Positioned.fill(
              child: pw.Opacity(
                opacity: isDark ? 0.20 : 0.12,
                child: pw.Image(ticketBgImage, fit: pw.BoxFit.cover),
              ),
            ),

          // 3. Crisp Card Content Layout
          pw.Positioned.fill(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Left 63%: Partner branding & Offer info
                pw.Expanded(
                  flex: 63,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
                          logoHeight: 14,
                          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                          textLightColor: isDark ? PdfColors.white : null,
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: pw.BoxDecoration(
                            color: palette.badgeBg,
                            borderRadius: pw.BorderRadius.circular(2),
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
                        pw.Text(
                          promotion.title,
                          style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: isDark ? PdfColors.white : palette.textPrimary),
                          maxLines: 2,
                        ),
                        pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: pw.BoxDecoration(
                                color: palette.codeBg,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                'CODICE: ${promotion.codePrefix}',
                                style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: palette.codeText, letterSpacing: 0.5),
                              ),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Text(
                              'Valido ${promotion.validityDays} gg',
                              style: pw.TextStyle(font: fontRegular, fontSize: 5, color: isDark ? PdfColor.fromHex('CBD5E1') : palette.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),


                // Right 37%: Dedicated QR Stub (100% Centered!)
                pw.Expanded(
                  flex: 37,
                  child: pw.Container(
                    color: isDark ? PdfColor(0.04, 0.05, 0.08, 0.55) : PdfColors.white,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'ATTIVA IL PASS',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 5,
                            color: isDark ? palette.accentColor : palette.primaryBg,
                            letterSpacing: 0.4,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2.5),
                        // Clean White Square with Theme Border
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(color: palette.accentColor, width: 1),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: claimUrl,
                            width: 27,
                            height: 27,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 2.5),
                        pw.Text(
                          'INQUADRA CON FOTOCAMERA',
                          style: pw.TextStyle(
                            font: fontSemiBold,
                            fontSize: 3.8,
                            color: isDark ? PdfColors.white : PdfColors.grey700,
                            letterSpacing: 0.2,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        if (expDateStr != null) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Entro il $expDateStr',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 3.5,
                              color: isDark ? PdfColor.fromHex('F87171') : PdfColors.red800,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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

    pw.ImageProvider? ticketBgImage;
    if (theme == CouponVisualTheme.luxurySpa) {
      ticketBgImage = await _loadAssetImage('assets/images/coupons/spa_bg.jpg');
    } else if (theme == CouponVisualTheme.sportDynamic) {
      ticketBgImage = await _loadAssetImage('assets/images/coupons/sport_bg.jpg');
    }

    final cardFormat = PdfPageFormat(
      85 * PdfPageFormat.mm,
      55 * PdfPageFormat.mm,
      marginAll: ticketBgImage != null ? 0 : 2.5 * PdfPageFormat.mm,
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
            ticketBgImage: ticketBgImage,
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

    pw.ImageProvider? flyerBgImage;
    if (theme == CouponVisualTheme.luxurySpa) {
      flyerBgImage = await _loadAssetImage('assets/images/coupons/spa_bg.jpg');
    } else if (theme == CouponVisualTheme.sportDynamic) {
      flyerBgImage = await _loadAssetImage('assets/images/coupons/sport_bg.jpg');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(10),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: isDark ? palette.primaryBg : PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: palette.accentColor, width: 1.5),
            ),
            child: pw.Column(
              children: [
                // 1. Top Hero Photo Banner
                if (flyerBgImage != null)
                  pw.Container(
                    height: 120,
                    width: double.infinity,
                    child: pw.ClipRRect(
                      horizontalRadius: 8.5,
                      verticalRadius: 8.5,
                      child: pw.Stack(
                        children: [
                          pw.Positioned.fill(
                            child: pw.Image(flyerBgImage, fit: pw.BoxFit.cover),
                          ),
                          pw.Positioned(
                            top: 8,
                            right: 8,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: PdfColor(0.04, 0.05, 0.08, 0.75),
                                borderRadius: pw.BorderRadius.circular(12),
                                border: pw.Border.all(color: palette.accentColor, width: 0.8),
                              ),
                              child: pw.Text(
                                'PROMOZIONE ESCLUSIVA',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 5.5,
                                  color: palette.badgeText,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  pw.Container(
                    width: double.infinity,
                    height: 48,
                    decoration: pw.BoxDecoration(
                      color: palette.primaryBg,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(8.5)),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: pw.Center(
                      child: pw.Text(
                        'PROMOZIONE ESCLUSIVA',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          color: palette.badgeText,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                // 2. Co-branding bar (hairline divider, NO 'x')
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: isDark ? PdfColor.fromHex('0B1120') : PdfColor.fromHex('F8FAFC'),
                    border: pw.Border(
                      bottom: pw.BorderSide(color: palette.borderColor, width: 0.8),
                    ),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      _buildHeaderLogos(
                        orgLogoImage: orgLogoImage,
                        partnerLogoImage: partnerLogoImage,
                        orgName: orgName,
                        promotion: promotion,
                        fontBold: fontBold,
                        fontSemiBold: fontSemiBold,
                        logoHeight: 18,
                        alignment: pw.MainAxisAlignment.center,
                        overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                        textLightColor: isDark ? PdfColors.white : null,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty
                            ? 'CONVENZIONE ESCLUSIVA SOCI ${promotion.partnerName!.toUpperCase()}'
                            : 'PROMOZIONE UFFICIALE',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 6,
                          color: palette.badgeText,
                          letterSpacing: 0.8,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // 3. Main Content
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Badge & Title
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: pw.BoxDecoration(
                                color: palette.badgeBg,
                                borderRadius: pw.BorderRadius.circular(10),
                                border: pw.Border.all(color: palette.accentColor, width: 0.8),
                              ),
                              child: pw.Text(
                                promotion.offerType.label.toUpperCase(),
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 6.5,
                                  color: palette.badgeText,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              promotion.title,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: isDark ? PdfColors.white : palette.primaryBg,
                              ),
                              textAlign: pw.TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                        ),

                        // QR Callout Card
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: isDark ? PdfColor.fromHex('1E293B') : PdfColor.fromHex('F8FAFC'),
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: palette.accentColor, width: 1),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.all(4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(6),
                                  border: pw.Border.all(color: palette.accentColor, width: 0.8),
                                ),
                                child: pw.BarcodeWidget(
                                  barcode: pw.Barcode.qrCode(),
                                  data: claimUrl,
                                  width: 52,
                                  height: 52,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.SizedBox(width: 10),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    pw.Text(
                                      'ATTIVA IL PASS',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 7.5,
                                        color: isDark ? palette.accentColor : palette.primaryBg,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      'Inquadra con la fotocamera dello smartphone per riscattare l\'offerta.',
                                      style: pw.TextStyle(
                                        font: fontRegular,
                                        fontSize: 6,
                                        color: isDark ? PdfColor.fromHex('CBD5E1') : PdfColor.fromHex('475569'),
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      expDateStr != null
                                          ? 'Entro $expDateStr • Valido ${promotion.validityDays} gg'
                                          : 'Valido ${promotion.validityDays} giorni',
                                      style: pw.TextStyle(
                                        font: fontSemiBold,
                                        fontSize: 5.5,
                                        color: palette.badgeText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Mini 3 steps footer
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: isDark ? PdfColor.fromHex('0B1120') : PdfColor.fromHex('F1F5F9'),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '1. Inquadra  2. Registrati  3. Mostra pass',
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 5,
                                  color: isDark ? PdfColor.fromHex('CBD5E1') : PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                'ticketto.it',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 5,
                                  color: palette.accentColor,
                                ),
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

    pw.ImageProvider? ticketBgImage;
    if (theme == CouponVisualTheme.luxurySpa) {
      ticketBgImage = await _loadAssetImage('assets/images/coupons/spa_bg.jpg');
    } else if (theme == CouponVisualTheme.sportDynamic) {
      ticketBgImage = await _loadAssetImage('assets/images/coupons/sport_bg.jpg');
    }

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
                ticketBgImage: ticketBgImage,
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
