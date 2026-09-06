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
  // Stepped tonal surfaces for depth without gradients
  final PdfColor surfaceLevel0; // Deepest canvas
  final PdfColor surfaceLevel1; // Card body / sections
  final PdfColor surfaceLevel2; // Recessed panels (QR area, code pill bg)

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
    required this.surfaceLevel0,
    required this.surfaceLevel1,
    required this.surfaceLevel2,
  });

  factory _ThemePalette.fromTheme(CouponVisualTheme theme) {
    switch (theme) {
      case CouponVisualTheme.luxurySpa:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('0F172A'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('94A3B8'),
          accentColor: PdfColor.fromHex('D97706'),
          accentText: PdfColors.white,
          borderColor: PdfColor.fromHex('334155'),
          dividerColor: PdfColor.fromHex('475569'),
          badgeBg: PdfColor.fromHex('1E293B'),
          badgeText: PdfColor.fromHex('FCD34D'),
          codeBg: PdfColor.fromHex('D97706'),
          codeText: PdfColors.white,
          surfaceLevel0: PdfColor.fromHex('0B1120'),
          surfaceLevel1: PdfColor.fromHex('1E293B'),
          surfaceLevel2: PdfColor.fromHex('0F172A'),
        );
      case CouponVisualTheme.sportDynamic:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('09090B'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('A1A1AA'),
          accentColor: PdfColor.fromHex('84CC16'),
          accentText: PdfColor.fromHex('09090B'),
          borderColor: PdfColor.fromHex('27272A'),
          dividerColor: PdfColor.fromHex('3F3F46'),
          badgeBg: PdfColor.fromHex('18181B'),
          badgeText: PdfColor.fromHex('A3E635'),
          codeBg: PdfColor.fromHex('84CC16'),
          codeText: PdfColor.fromHex('09090B'),
          surfaceLevel0: PdfColor.fromHex('09090B'),
          surfaceLevel1: PdfColor.fromHex('18181B'),
          surfaceLevel2: PdfColor.fromHex('27272A'),
        );
      case CouponVisualTheme.modernMinimal:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('F8FAFC'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColor.fromHex('0F172A'),
          textSecondary: PdfColor.fromHex('64748B'),
          accentColor: PdfColor.fromHex('4338CA'),
          accentText: PdfColors.white,
          borderColor: PdfColor.fromHex('E2E8F0'),
          dividerColor: PdfColor.fromHex('CBD5E1'),
          badgeBg: PdfColor.fromHex('EEF2FF'),
          badgeText: PdfColor.fromHex('4338CA'),
          codeBg: PdfColor.fromHex('4338CA'),
          codeText: PdfColors.white,
          surfaceLevel0: PdfColors.white,
          surfaceLevel1: PdfColor.fromHex('F8FAFC'),
          surfaceLevel2: PdfColor.fromHex('EEF2FF'),
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
  /// Double-hairline banknote frame, hero photo, large QR, editorial typography.
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

    pw.ImageProvider? heroBgImage;
    if (theme == CouponVisualTheme.luxurySpa) {
      heroBgImage = await _loadAssetImage('assets/images/coupons/spa_bg.jpg');
    } else if (theme == CouponVisualTheme.sportDynamic) {
      heroBgImage = await _loadAssetImage('assets/images/coupons/sport_bg.jpg');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          // Double-hairline banknote frame
          return pw.Container(
            padding: const pw.EdgeInsets.all(3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: palette.accentColor, width: 0.8),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: palette.surfaceLevel0,
                border: pw.Border.all(color: palette.borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  // 1. HERO PHOTO BANNER (top ~35%)
                  pw.Expanded(
                    flex: 35,
                    child: pw.Container(
                      width: double.infinity,
                      child: pw.ClipRRect(
                        horizontalRadius: 5.5,
                        verticalRadius: 5.5,
                        child: pw.Stack(
                          children: [
                            // Background: photo or solid surface
                            pw.Positioned.fill(
                              child: pw.Container(color: palette.surfaceLevel1),
                            ),
                            if (heroBgImage != null)
                              pw.Positioned.fill(
                                child: pw.Image(heroBgImage, fit: pw.BoxFit.cover),
                              ),
                            // Floating badge (top-right)
                            pw.Positioned(
                              top: 16,
                              right: 16,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: pw.BoxDecoration(
                                  color: palette.surfaceLevel0,
                                  borderRadius: pw.BorderRadius.circular(4),
                                  border: pw.Border.all(color: palette.accentColor, width: 0.5),
                                ),
                                child: pw.Text(
                                  promotion.isPartnership ? 'CONVENZIONE PARTNER' : 'PROMOZIONE ESCLUSIVA',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 8,
                                    color: palette.badgeText,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                            ),
                            // Co-branding lockup (bottom-left)
                            pw.Positioned(
                              bottom: 14,
                              left: 16,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: pw.BoxDecoration(
                                  color: palette.surfaceLevel0,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: _buildHeaderLogos(
                                  orgLogoImage: orgLogoImage,
                                  partnerLogoImage: partnerLogoImage,
                                  orgName: orgName,
                                  promotion: promotion,
                                  fontBold: fontBold,
                                  fontSemiBold: fontSemiBold,
                                  logoHeight: 22,
                                  overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                                  textLightColor: isDark ? PdfColors.white : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. MAIN PROPOSITION (middle ~30%)
                  pw.Expanded(
                    flex: 30,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Category pill
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: palette.surfaceLevel1,
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(color: palette.borderColor, width: 0.5),
                            ),
                            child: pw.Text(
                              promotion.offerType.label.toUpperCase(),
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: palette.badgeText,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 14),
                          // Headline
                          pw.Text(
                            promotion.title,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 28,
                              color: palette.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 10),
                            pw.Container(
                              constraints: const pw.BoxConstraints(maxWidth: 420),
                              child: pw.Text(
                                promotion.description!,
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                  lineSpacing: 2.0,
                                ),
                                textAlign: pw.TextAlign.center,
                                maxLines: 3,
                              ),
                            ),
                          ],
                          if (promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Riservata ai soci ${promotion.partnerName!}',
                              style: pw.TextStyle(
                                font: fontSemiBold,
                                fontSize: 10,
                                color: palette.accentColor,
                                letterSpacing: 0.5,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Hairline divider
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 40),
                    height: 0.5,
                    color: palette.borderColor,
                  ),

                  // 3. SCAN HUB (bottom ~35%)
                  pw.Expanded(
                    flex: 35,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          // QR + Instructions row
                          pw.Container(
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              color: palette.surfaceLevel1,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                // QR on white ground
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(10),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(6),
                                    border: pw.Border.all(color: palette.borderColor, width: 0.5),
                                  ),
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: claimUrl,
                                    width: 140,
                                    height: 140,
                                    color: PdfColors.black,
                                  ),
                                ),
                                pw.SizedBox(width: 24),
                                // Instructions
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    mainAxisSize: pw.MainAxisSize.min,
                                    children: [
                                      pw.Text(
                                        'ATTIVA IL TUO PASS',
                                        style: pw.TextStyle(
                                          font: fontBold,
                                          fontSize: 16,
                                          color: palette.accentColor,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      pw.SizedBox(height: 8),
                                      pw.Text(
                                        'Inquadra il QR code con la fotocamera dello smartphone per registrarti e sbloccare la convenzione.',
                                        style: pw.TextStyle(
                                          font: fontRegular,
                                          fontSize: 10,
                                          color: palette.textSecondary,
                                          lineSpacing: 1.5,
                                        ),
                                      ),
                                      pw.SizedBox(height: 12),
                                      // Validity info
                                      pw.Container(
                                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: pw.BoxDecoration(
                                          color: palette.surfaceLevel2,
                                          borderRadius: pw.BorderRadius.circular(4),
                                        ),
                                        child: pw.Text(
                                          expDateStr != null
                                              ? 'Attiva entro il $expDateStr  •  Valido ${promotion.validityDays} giorni'
                                              : 'Validità: ${promotion.validityDays} giorni dall\'attivazione',
                                          style: pw.TextStyle(
                                            font: fontSemiBold,
                                            fontSize: 9,
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

                          pw.SizedBox(height: 12),

                          // 3-step inline footer
                          pw.Text(
                            '1. Inquadra il QR   •   2. Inserisci nome ed email   •   3. Mostra il pass alla reception',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 8,
                              color: palette.textSecondary,
                              letterSpacing: 0.3,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom brand bar
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: palette.surfaceLevel1,
                      borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5.5)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Piattaforma Gestione Pass & Convenzioni',
                          style: pw.TextStyle(font: fontRegular, fontSize: 7, color: palette.textSecondary),
                        ),
                        pw.Text(
                          'Powered by ticketto.it',
                          style: pw.TextStyle(font: fontBold, fontSize: 7, color: palette.accentColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
  /// Reusable Split-Card Widget: brand spine + ticket notch + clean QR stub.
  /// Used for standard business card (85x55mm). Min font: 6.5pt.
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
    // Page background for ticket notch cutouts
    final pageBg = isGridItem ? PdfColors.white : (isDark ? palette.surfaceLevel0 : PdfColors.white);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: palette.surfaceLevel0,
        border: isGridItem
            ? pw.Border.all(color: PdfColors.grey400, width: 0.5, style: pw.BorderStyle.dashed)
            : null,
      ),
      child: pw.Stack(
        children: [
          // Subtle background texture
          if (ticketBgImage != null)
            pw.Positioned.fill(
              child: pw.Opacity(
                opacity: isDark ? 0.45 : 0.30,
                child: pw.Image(ticketBgImage, fit: pw.BoxFit.cover),
              ),
            ),

          // Main content with brand spine
          pw.Positioned.fill(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Brand spine (accent color bar on left edge)
                pw.Container(
                  width: 3,
                  color: palette.accentColor,
                ),

                // Left body (62%): branding + offer
                pw.Expanded(
                  flex: 62,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(7, 5, 4, 5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Header: logo + partner
                        _buildHeaderLogos(
                          orgLogoImage: orgLogoImage,
                          partnerLogoImage: partnerLogoImage,
                          orgName: orgName,
                          promotion: promotion,
                          fontBold: fontBold,
                          fontSemiBold: fontSemiBold,
                          logoHeight: 12,
                          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                          textLightColor: isDark ? PdfColors.white : null,
                        ),
                        // Offer headline
                        pw.Text(
                          promotion.title,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: palette.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                        ),
                        // Footer: code + validity
                        pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: pw.BoxDecoration(
                                color: palette.codeBg,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                'COD: ${promotion.codePrefix}',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 7,
                                  color: palette.codeText,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(
                                expDateStr != null
                                    ? 'Scad. $expDateStr'
                                    : '${promotion.validityDays} gg',
                                style: pw.TextStyle(
                                  font: fontRegular,
                                  fontSize: 6.5,
                                  color: palette.textSecondary,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Right stub (38%): QR area
                pw.Expanded(
                  flex: 38,
                  child: pw.Container(
                    color: palette.surfaceLevel1,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'INQUADRA IL QR',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 6.5,
                            color: palette.accentColor,
                            letterSpacing: 1.0,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 3),
                        // QR on white ground with quiet zone
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(2),
                            border: pw.Border.all(color: palette.borderColor, width: 0.5),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: claimUrl,
                            width: 34,
                            height: 34,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Attiva il pass',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 6.5,
                            color: palette.textSecondary,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ticket notch cutouts (semicircles at the divider line, ~62% from left)
          pw.Positioned(
            top: -5,
            right: 0,
            child: pw.SizedBox(
              width: 56, // ~38% of 148pt (85mm card width)
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 10,
                  height: 10,
                  decoration: pw.BoxDecoration(
                    color: pageBg,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          pw.Positioned(
            bottom: -5,
            right: 0,
            child: pw.SizedBox(
              width: 56,
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 10,
                  height: 10,
                  decoration: pw.BoxDecoration(
                    color: pageBg,
                    shape: pw.BoxShape.circle,
                  ),
                ),
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

  /// 3. Flyer A6 (105 x 148 mm) — vertical boutique certificate with 4-zone flow.
  /// Double-hairline frame, editorial typography, min font 7pt.
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
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          // Double-hairline frame
          return pw.Container(
            padding: const pw.EdgeInsets.all(2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: palette.accentColor, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: palette.surfaceLevel0,
                border: pw.Border.all(color: palette.borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  // ZONE 1: Hero visual (25%)
                  pw.Expanded(
                    flex: 25,
                    child: pw.Container(
                      width: double.infinity,
                      child: pw.ClipRRect(
                        horizontalRadius: 3.5,
                        verticalRadius: 3.5,
                        child: pw.Stack(
                          children: [
                            pw.Positioned.fill(
                              child: pw.Container(color: palette.surfaceLevel1),
                            ),
                            if (flyerBgImage != null)
                              pw.Positioned.fill(
                                child: pw.Image(flyerBgImage, fit: pw.BoxFit.cover),
                              ),
                            // Badge
                            pw.Positioned(
                              top: 8,
                              right: 8,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: palette.surfaceLevel0,
                                  borderRadius: pw.BorderRadius.circular(3),
                                  border: pw.Border.all(color: palette.accentColor, width: 0.5),
                                ),
                                child: pw.Text(
                                  promotion.isPartnership ? 'CONVENZIONE' : 'ESCLUSIVA',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 7,
                                    color: palette.badgeText,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            // Co-branding
                            pw.Positioned(
                              bottom: 8,
                              left: 8,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: palette.surfaceLevel0,
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                                child: _buildHeaderLogos(
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ZONE 2: Offer content (35%)
                  pw.Expanded(
                    flex: 35,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Category pill
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: pw.BoxDecoration(
                              color: palette.surfaceLevel1,
                              borderRadius: pw.BorderRadius.circular(3),
                              border: pw.Border.all(color: palette.borderColor, width: 0.5),
                            ),
                            child: pw.Text(
                              promotion.offerType.label.toUpperCase(),
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 7.5,
                                color: palette.badgeText,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          // Title
                          pw.Text(
                            promotion.title,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 18,
                              color: palette.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            textAlign: pw.TextAlign.center,
                            maxLines: 2,
                          ),
                          if (promotion.description != null && promotion.description!.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              promotion.description!,
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 8.5,
                                color: palette.textSecondary,
                                lineSpacing: 1.5,
                              ),
                              textAlign: pw.TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                          if (promotion.isPartnership && promotion.partnerName != null && promotion.partnerName!.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Riservata ai soci ${promotion.partnerName!}',
                              style: pw.TextStyle(
                                font: fontSemiBold,
                                fontSize: 7.5,
                                color: palette.accentColor,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Hairline divider
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 20),
                    height: 0.5,
                    color: palette.borderColor,
                  ),

                  // ZONE 3: QR panel (28%)
                  pw.Expanded(
                    flex: 28,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: palette.surfaceLevel1,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            // QR code
                            pw.Container(
                              padding: const pw.EdgeInsets.all(5),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(4),
                                border: pw.Border.all(color: palette.borderColor, width: 0.5),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: claimUrl,
                                width: 68,
                                height: 68,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            // Instructions
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text(
                                    'ATTIVA IL PASS',
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 9,
                                      color: palette.accentColor,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    'Inquadra il QR con la fotocamera per registrarti.',
                                    style: pw.TextStyle(
                                      font: fontRegular,
                                      fontSize: 7.5,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                  pw.SizedBox(height: 5),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: pw.BoxDecoration(
                                      color: palette.surfaceLevel2,
                                      borderRadius: pw.BorderRadius.circular(3),
                                    ),
                                    child: pw.Text(
                                      expDateStr != null
                                          ? 'Entro $expDateStr  •  ${promotion.validityDays} gg'
                                          : 'Valido ${promotion.validityDays} giorni',
                                      style: pw.TextStyle(
                                        font: fontSemiBold,
                                        fontSize: 7,
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
                    ),
                  ),

                  // ZONE 4: Footer (12%)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: palette.surfaceLevel1,
                      borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(3.5)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '1. Inquadra  •  2. Registrati  •  3. Mostra pass',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 7,
                            color: palette.textSecondary,
                          ),
                        ),
                        pw.Text(
                          'Powered by ticketto.it',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 7,
                            color: palette.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Grid coupon item — dedicated layout for ~95×85mm cells (NOT 85×55mm business card).
  /// Wider aspect ratio, larger fonts, bigger QR.
  static pw.Widget _buildGridCouponItem({
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
    pw.ImageProvider? ticketBgImage,
  }) {
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme != CouponVisualTheme.modernMinimal;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: palette.surfaceLevel0,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5, style: pw.BorderStyle.dashed),
      ),
      child: pw.Stack(
        children: [
          // Subtle background texture
          if (ticketBgImage != null)
            pw.Positioned.fill(
              child: pw.Opacity(
                opacity: isDark ? 0.40 : 0.25,
                child: pw.Image(ticketBgImage, fit: pw.BoxFit.cover),
              ),
            ),

          // Content
          pw.Positioned.fill(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Brand spine
                pw.Container(
                  width: 4,
                  color: palette.accentColor,
                ),

                // Left section (65%): branding + offer
                pw.Expanded(
                  flex: 65,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(10, 8, 6, 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Top: logo lockup
                        _buildHeaderLogos(
                          orgLogoImage: orgLogoImage,
                          partnerLogoImage: partnerLogoImage,
                          orgName: orgName,
                          promotion: promotion,
                          fontBold: fontBold,
                          fontSemiBold: fontSemiBold,
                          logoHeight: 16,
                          overridePartnerLogoDarkBg: overridePartnerLogoDarkBg,
                          textLightColor: isDark ? PdfColors.white : null,
                        ),
                        // Headline
                        pw.Text(
                          promotion.title,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: palette.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                        ),
                        // Description (if available, 1 line)
                        if (promotion.description != null && promotion.description!.trim().isNotEmpty)
                          pw.Text(
                            promotion.description!,
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 7.5,
                              color: palette.textSecondary,
                            ),
                            maxLines: 1,
                          ),
                        // Code + validity
                        pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: palette.codeBg,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                'COD: ${promotion.codePrefix}',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 8.5,
                                  color: palette.codeText,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              expDateStr != null
                                  ? 'Scad. $expDateStr'
                                  : '${promotion.validityDays} gg',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 7,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Right section (35%): QR stub
                pw.Expanded(
                  flex: 35,
                  child: pw.Container(
                    color: palette.surfaceLevel1,
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'SCAN PER ATTIVARE',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 7,
                            color: palette.accentColor,
                            letterSpacing: 1.0,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(color: palette.borderColor, width: 0.5),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: claimUrl,
                            width: 42,
                            height: 42,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Attiva il pass digitale',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 7,
                            color: palette.textSecondary,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ticket notches at the stub boundary
          pw.Positioned(
            top: -5,
            right: 0,
            child: pw.SizedBox(
              width: 70, // ~35% of cell width
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 10,
                  height: 10,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          pw.Positioned(
            bottom: -5,
            right: 0,
            child: pw.SizedBox(
              width: 70,
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 10,
                  height: 10,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Foglio A4 a griglia (6 coupon identici) — uses dedicated grid layout widget.
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
              return _buildGridCouponItem(
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
