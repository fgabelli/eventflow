import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/constants/app_constants.dart';

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

enum ThemeCategory {
  base,
  occasion,
}

enum CouponVisualTheme {
  // Stili Base / Settoriali
  modernMinimal(
    'Clean Modern',
    'Stile chiaro, minimale ed essenziale. Universale per qualsiasi settore o brand.',
    category: ThemeCategory.base,
  ),
  sportDynamic(
    'Sport & Dynamic Energy',
    'Contrasto ad alta energia nero grafite e verde lime fluo. Ideale per palestre, fitness e sport.',
    category: ThemeCategory.base,
  ),
  luxurySpa(
    'Luxury Dark & Gold',
    'Sfondo blu ardesia con finiture in oro caldo. Ideale per SPA, hotel, ristoranti ed esperienze di pregio.',
    category: ThemeCategory.base,
  ),

  // Ricorrenze & Feste
  christmas(
    'Natale & Festività',
    'Rosso granata profondo, accenti oro caldo e finiture festive eleganti per cene, voucher e regali.',
    category: ThemeCategory.occasion,
    occasionTag: 'SPECIALE NATALE',
  ),
  valentine(
    'San Valentino & Coppia',
    'Borgogna vellutato, accenti rosa e oro caldo per regali romantici ed esperienze per due.',
    category: ThemeCategory.occasion,
    occasionTag: 'EDIZIONE SAN VALENTINO',
  ),
  birthday(
    'Compleanno & Party',
    'Blu notte festivo con accenti oro brillante e dettagli celebrativi per regali di compleanno.',
    category: ThemeCategory.occasion,
    occasionTag: 'BUON COMPLEANNO',
  ),
  anniversary(
    'Anniversario & Gold',
    'Obsidian Black puro e oro metallizzato imperiale per traguardi ed edizioni speciali di prestigio.',
    category: ThemeCategory.occasion,
    occasionTag: 'EDIZIONE ANNIVERSARIO',
  ),
  motherDay(
    'Festa della Mamma',
    'Rosa antico e crema calda con accenti bacca per regali delicati e coccole speciali.',
    category: ThemeCategory.occasion,
    occasionTag: 'FESTA DELLA MAMMA',
  ),
  fatherDay(
    'Festa del Papà',
    'Blu petrolio scuro, grigio antracite e accenti cuoio cognac per tempo libero, sport ed esperienze.',
    category: ThemeCategory.occasion,
    occasionTag: 'FESTA DEL PAPÀ',
  );

  final String label;
  final String description;
  final ThemeCategory category;
  final String? occasionTag;

  const CouponVisualTheme(
    this.label,
    this.description, {
    this.category = ThemeCategory.base,
    this.occasionTag,
  });

  bool get isOccasion => category == ThemeCategory.occasion;
  bool get isDark => this != modernMinimal && this != motherDay;
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
      case CouponVisualTheme.christmas:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('3B0A12'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('E2C2C6'),
          accentColor: PdfColor.fromHex('EAB308'),
          accentText: PdfColor.fromHex('3B0A12'),
          borderColor: PdfColor.fromHex('5C1D24'),
          dividerColor: PdfColor.fromHex('782632'),
          badgeBg: PdfColor.fromHex('2B070D'),
          badgeText: PdfColor.fromHex('FDE047'),
          codeBg: PdfColor.fromHex('EAB308'),
          codeText: PdfColor.fromHex('3B0A12'),
          surfaceLevel0: PdfColor.fromHex('220409'),
          surfaceLevel1: PdfColor.fromHex('3B0A12'),
          surfaceLevel2: PdfColor.fromHex('500E19'),
        );
      case CouponVisualTheme.valentine:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('2A0818'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('E5B8D0'),
          accentColor: PdfColor.fromHex('FB7185'),
          accentText: PdfColor.fromHex('2A0818'),
          borderColor: PdfColor.fromHex('4C1D33'),
          dividerColor: PdfColor.fromHex('6B2147'),
          badgeBg: PdfColor.fromHex('1D0511'),
          badgeText: PdfColor.fromHex('FDA4AF'),
          codeBg: PdfColor.fromHex('F43F5E'),
          codeText: PdfColors.white,
          surfaceLevel0: PdfColor.fromHex('1A030E'),
          surfaceLevel1: PdfColor.fromHex('2A0818'),
          surfaceLevel2: PdfColor.fromHex('3D1026'),
        );
      case CouponVisualTheme.birthday:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('111827'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('9CA3AF'),
          accentColor: PdfColor.fromHex('F59E0B'),
          accentText: PdfColor.fromHex('111827'),
          borderColor: PdfColor.fromHex('374151'),
          dividerColor: PdfColor.fromHex('4B5563'),
          badgeBg: PdfColor.fromHex('1F2937'),
          badgeText: PdfColor.fromHex('FBBF24'),
          codeBg: PdfColor.fromHex('F59E0B'),
          codeText: PdfColor.fromHex('111827'),
          surfaceLevel0: PdfColor.fromHex('0B0F17'),
          surfaceLevel1: PdfColor.fromHex('1F2937'),
          surfaceLevel2: PdfColor.fromHex('374151'),
        );
      case CouponVisualTheme.anniversary:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('0A0A0A'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('A3A3A3'),
          accentColor: PdfColor.fromHex('D4AF37'),
          accentText: PdfColor.fromHex('0A0A0A'),
          borderColor: PdfColor.fromHex('262626'),
          dividerColor: PdfColor.fromHex('404040'),
          badgeBg: PdfColor.fromHex('171717'),
          badgeText: PdfColor.fromHex('FCD34D'),
          codeBg: PdfColor.fromHex('D4AF37'),
          codeText: PdfColor.fromHex('0A0A0A'),
          surfaceLevel0: PdfColor.fromHex('050505'),
          surfaceLevel1: PdfColor.fromHex('141414'),
          surfaceLevel2: PdfColor.fromHex('1F1F1F'),
        );
      case CouponVisualTheme.motherDay:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('FFF8F6'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColor.fromHex('2D1820'),
          textSecondary: PdfColor.fromHex('7C5966'),
          accentColor: PdfColor.fromHex('BE185D'),
          accentText: PdfColors.white,
          borderColor: PdfColor.fromHex('FCE7F0'),
          dividerColor: PdfColor.fromHex('F3D0DF'),
          badgeBg: PdfColor.fromHex('FDF2F8'),
          badgeText: PdfColor.fromHex('BE185D'),
          codeBg: PdfColor.fromHex('BE185D'),
          codeText: PdfColors.white,
          surfaceLevel0: PdfColors.white,
          surfaceLevel1: PdfColor.fromHex('FFF8F6'),
          surfaceLevel2: PdfColor.fromHex('FCE7F0'),
        );
      case CouponVisualTheme.fatherDay:
        return _ThemePalette(
          primaryBg: PdfColor.fromHex('0B192C'),
          qrSectionBg: PdfColors.white,
          textPrimary: PdfColors.white,
          textSecondary: PdfColor.fromHex('94A3B8'),
          accentColor: PdfColor.fromHex('EA580C'),
          accentText: PdfColors.white,
          borderColor: PdfColor.fromHex('1E3E62'),
          dividerColor: PdfColor.fromHex('2C5282'),
          badgeBg: PdfColor.fromHex('091422'),
          badgeText: PdfColor.fromHex('FB923C'),
          codeBg: PdfColor.fromHex('EA580C'),
          codeText: PdfColors.white,
          surfaceLevel0: PdfColor.fromHex('060E18'),
          surfaceLevel1: PdfColor.fromHex('0F2238'),
          surfaceLevel2: PdfColor.fromHex('1B3B5C'),
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

  /// Safely loads the background texture image for a specific theme.
  static Future<pw.ImageProvider?> _loadThemeBgImage(CouponVisualTheme theme) async {
    final assetPath = switch (theme) {
      CouponVisualTheme.luxurySpa => 'assets/images/coupons/spa_bg.jpg',
      CouponVisualTheme.sportDynamic => 'assets/images/coupons/sport_bg.jpg',
      CouponVisualTheme.christmas => 'assets/images/coupons/christmas_bg.jpg',
      CouponVisualTheme.valentine => 'assets/images/coupons/valentine_bg.jpg',
      CouponVisualTheme.birthday => 'assets/images/coupons/birthday_bg.jpg',
      CouponVisualTheme.anniversary => 'assets/images/coupons/anniversary_bg.jpg',
      CouponVisualTheme.motherDay => 'assets/images/coupons/mother_bg.jpg',
      CouponVisualTheme.fatherDay => 'assets/images/coupons/father_bg.jpg',
      CouponVisualTheme.modernMinimal => null,
    };
    if (assetPath == null) return null;
    return _loadAssetImage(assetPath);
  }

  static const String _waIconBase64 = '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';

  /// Loads the WhatsApp logo (from asset bundle or embedded base64 fallback).
  static Future<pw.ImageProvider?> _loadWhatsappIcon() async {
    final fromAsset = await _loadAssetImage('assets/icons/whatsapp.png');
    if (fromAsset != null) return fromAsset;
    try {
      return pw.MemoryImage(base64Decode(_waIconBase64));
    } catch (_) {
      return null;
    }
  }

  /// Builds a WhatsApp snippet with official icon or 'WA ' text fallback.
  static pw.Widget _buildWhatsappSnippet({
    required String number,
    required pw.ImageProvider? waIcon,
    required pw.Font font,
    required double fontSize,
    required PdfColor color,
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (waIcon != null)
          pw.Container(
            width: fontSize * 1.18,
            height: fontSize * 1.18,
            margin: const pw.EdgeInsets.only(right: 2.5),
            child: pw.Image(waIcon),
          )
        else
          pw.Text('WA ', style: pw.TextStyle(font: font, fontSize: fontSize, color: color)),
        pw.Text(number, style: pw.TextStyle(font: font, fontSize: fontSize, color: color)),
      ],
    );
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
    String? orgEmail,
    String? orgPhone,
    String? orgWhatsapp,
    String? orgWebsite,
    String? orgAddress,
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
          orgEmail: orgEmail,
          orgPhone: orgPhone,
          orgWhatsapp: orgWhatsapp,
          orgWebsite: orgWebsite,
          orgAddress: orgAddress,
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
          orgEmail: orgEmail,
          orgPhone: orgPhone,
          orgWhatsapp: orgWhatsapp,
          orgWebsite: orgWebsite,
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
          orgEmail: orgEmail,
          orgPhone: orgPhone,
          orgWhatsapp: orgWhatsapp,
          orgWebsite: orgWebsite,
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
          orgEmail: orgEmail,
          orgPhone: orgPhone,
          orgWhatsapp: orgWhatsapp,
          orgWebsite: orgWebsite,
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
    String? orgEmail,
    String? orgPhone,
    String? orgWhatsapp,
    String? orgWebsite,
    String? orgAddress,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? AppConfig.baseUrl;
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme.isDark;

    final heroBgImage = await _loadThemeBgImage(theme);

    final waIcon = await _loadWhatsappIcon();

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
                              theme.occasionTag != null
                                  ? '${theme.occasionTag!}  |  ${promotion.offerType.label.toUpperCase()}'
                                  : promotion.offerType.label.toUpperCase(),
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
                                              ? 'Attiva entro il $expDateStr  |  Validità: ${promotion.validityDescription} dalla registrazione'
                                              : 'Validità: ${promotion.validityDescription} dalla registrazione',
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
                            '1. Inquadra il QR   |   2. Inserisci nome ed email   |   3. Mostra il pass alla reception',
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
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: pw.BoxDecoration(
                      color: palette.surfaceLevel1,
                      borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(5.5)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Org contact info (2 lines)
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                [
                                  orgName,
                                  if (orgAddress != null && orgAddress.trim().isNotEmpty) orgAddress,
                                ].join('  |  '),
                                style: pw.TextStyle(font: fontBold, fontSize: 7, color: palette.textPrimary),
                                maxLines: 1,
                              ),
                              if (orgPhone != null || orgWhatsapp != null || orgEmail != null || orgWebsite != null)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 2),
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      if (orgPhone != null && orgPhone.trim().isNotEmpty)
                                        pw.Text(
                                          'Tel: $orgPhone',
                                          style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: palette.textSecondary),
                                        ),
                                      if (orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty) ...[
                                        if (orgPhone != null && orgPhone.trim().isNotEmpty)
                                          pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: palette.textSecondary)),
                                        _buildWhatsappSnippet(
                                          number: orgWhatsapp,
                                          waIcon: waIcon,
                                          font: fontRegular,
                                          fontSize: 6.5,
                                          color: palette.textSecondary,
                                        ),
                                      ],
                                      if (orgEmail != null && orgEmail.trim().isNotEmpty) ...[
                                        if ((orgPhone != null && orgPhone.trim().isNotEmpty) || (orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty))
                                          pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: palette.textSecondary)),
                                        pw.Text(
                                          orgEmail,
                                          style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: palette.textSecondary),
                                        ),
                                      ],
                                      if (orgWebsite != null && orgWebsite.trim().isNotEmpty) ...[
                                        pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: palette.textSecondary)),
                                        pw.Text(
                                          orgWebsite,
                                          style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: palette.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text(
                          'Powered by ticketto.it',
                          style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: palette.accentColor),
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
    String? orgPhone,
    String? orgWhatsapp,
    String? orgEmail,
    String? orgWebsite,
    pw.ImageProvider? waIcon,
  }) {
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme.isDark;
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
                        // Occasion tag if present
                        if (theme.occasionTag != null)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: pw.BoxDecoration(
                              color: palette.surfaceLevel2,
                              borderRadius: pw.BorderRadius.circular(2),
                              border: pw.Border.all(color: palette.borderColor, width: 0.5),
                            ),
                            child: pw.Text(
                              theme.occasionTag!,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 4.8,
                                color: palette.badgeText,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        // Offer headline
                        pw.Text(
                          promotion.title,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: theme.occasionTag != null ? 10 : 11,
                            color: palette.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                        ),
                        // Footer: code + validity
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
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
                                  fontSize: 6.8,
                                  color: palette.codeText,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 2.5),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                              decoration: pw.BoxDecoration(
                                color: palette.surfaceLevel2,
                                borderRadius: pw.BorderRadius.circular(2),
                                border: pw.Border.all(color: palette.borderColor, width: 0.5),
                              ),
                              child: pw.Text(
                                expDateStr != null
                                    ? 'Entro $expDateStr | Validità ${promotion.validityDescription} dalla registrazione'
                                    : 'Validità: ${promotion.validityDescription} dalla registrazione',
                                style: pw.TextStyle(
                                  font: fontSemiBold,
                                  fontSize: 5.2,
                                  color: palette.badgeText,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        // Compact contact info (2 lines)
                        if (orgPhone != null || orgWhatsapp != null || orgEmail != null || orgWebsite != null)
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              if (orgPhone != null || orgWhatsapp != null)
                                pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    if (orgPhone != null && orgPhone.trim().isNotEmpty)
                                      pw.Text(
                                        'Tel $orgPhone',
                                        style: pw.TextStyle(
                                          font: fontRegular,
                                          fontSize: 4.8,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    if (orgPhone != null && orgPhone.trim().isNotEmpty && orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty)
                                      pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 4.8, color: palette.textSecondary)),
                                    if (orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty)
                                      _buildWhatsappSnippet(
                                        number: orgWhatsapp,
                                        waIcon: waIcon,
                                        font: fontRegular,
                                        fontSize: 4.8,
                                        color: palette.textSecondary,
                                      ),
                                  ],
                                ),
                              if (orgEmail != null || orgWebsite != null)
                                pw.Text(
                                  [
                                    if (orgEmail != null && orgEmail.trim().isNotEmpty) orgEmail,
                                    if (orgWebsite != null && orgWebsite.trim().isNotEmpty)
                                      orgWebsite.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'^www\.'), ''),
                                  ].join('  |  '),
                                  style: pw.TextStyle(
                                    font: fontRegular,
                                    fontSize: 4.8,
                                    color: palette.textSecondary,
                                  ),
                                  maxLines: 1,
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
    String? orgEmail,
    String? orgPhone,
    String? orgWhatsapp,
    String? orgWebsite,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? AppConfig.baseUrl;
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    final ticketBgImage = await _loadThemeBgImage(theme);

    final waIcon = await _loadWhatsappIcon();

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
            orgPhone: orgPhone,
            orgWhatsapp: orgWhatsapp,
            orgEmail: orgEmail,
            orgWebsite: orgWebsite,
            waIcon: waIcon,
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
    String? orgEmail,
    String? orgPhone,
    String? orgWhatsapp,
    String? orgWebsite,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? AppConfig.baseUrl;
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme.isDark;

    final flyerBgImage = await _loadThemeBgImage(theme);

    final waIcon = await _loadWhatsappIcon();

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
                              theme.occasionTag != null
                                  ? '${theme.occasionTag!}  |  ${promotion.offerType.label.toUpperCase()}'
                                  : promotion.offerType.label.toUpperCase(),
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
                                          ? 'Entro $expDateStr  |  Validità: ${promotion.validityDescription} dalla registrazione'
                                          : 'Validità: ${promotion.validityDescription} dalla registrazione',
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
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: palette.surfaceLevel1,
                      borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(3.5)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                orgName,
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 6.5,
                                  color: palette.textPrimary,
                                ),
                                maxLines: 1,
                              ),
                              if (orgPhone != null || orgWhatsapp != null || orgEmail != null || orgWebsite != null)
                                pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    if (orgPhone != null && orgPhone.trim().isNotEmpty)
                                      pw.Text(
                                        orgPhone,
                                        style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: palette.textSecondary),
                                      ),
                                    if (orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty) ...[
                                      if (orgPhone != null && orgPhone.trim().isNotEmpty)
                                        pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: palette.textSecondary)),
                                      _buildWhatsappSnippet(
                                        number: orgWhatsapp,
                                        waIcon: waIcon,
                                        font: fontRegular,
                                        fontSize: 5.5,
                                        color: palette.textSecondary,
                                      ),
                                    ],
                                    if (orgEmail != null && orgEmail.trim().isNotEmpty) ...[
                                      if ((orgPhone != null && orgPhone.trim().isNotEmpty) || (orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty))
                                        pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: palette.textSecondary)),
                                      pw.Text(
                                        orgEmail,
                                        style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: palette.textSecondary),
                                      ),
                                    ],
                                    if (orgWebsite != null && orgWebsite.trim().isNotEmpty) ...[
                                      pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: palette.textSecondary)),
                                      pw.Text(
                                        orgWebsite,
                                        style: pw.TextStyle(font: fontRegular, fontSize: 5.5, color: palette.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          'Powered by ticketto.it',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 6.5,
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
    String? orgPhone,
    String? orgWhatsapp,
    String? orgEmail,
    String? orgWebsite,
    pw.ImageProvider? waIcon,
  }) {
    final palette = _ThemePalette.fromTheme(theme);
    final isDark = theme.isDark;

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
                        // Occasion tag if present
                        if (theme.occasionTag != null)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: pw.BoxDecoration(
                              color: palette.surfaceLevel2,
                              borderRadius: pw.BorderRadius.circular(2),
                              border: pw.Border.all(color: palette.borderColor, width: 0.5),
                            ),
                            child: pw.Text(
                              theme.occasionTag!,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 5.5,
                                color: palette.badgeText,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        // Headline
                        pw.Text(
                          promotion.title,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: theme.occasionTag != null ? 13 : 14,
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
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: palette.surfaceLevel2,
                                borderRadius: pw.BorderRadius.circular(3),
                                border: pw.Border.all(color: palette.borderColor, width: 0.5),
                              ),
                              child: pw.Text(
                                expDateStr != null
                                    ? 'Entro $expDateStr | Validità: ${promotion.validityDescription} dalla registrazione'
                                    : 'Validità: ${promotion.validityDescription} dalla registrazione',
                                style: pw.TextStyle(
                                  font: fontSemiBold,
                                  fontSize: 6.5,
                                  color: palette.badgeText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Compact contact info (2 lines)
                        if (orgPhone != null || orgWhatsapp != null || orgEmail != null || orgWebsite != null)
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              if (orgPhone != null || orgWhatsapp != null)
                                pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    if (orgPhone != null && orgPhone.trim().isNotEmpty)
                                      pw.Text(
                                        'Tel $orgPhone',
                                        style: pw.TextStyle(
                                          font: fontRegular,
                                          fontSize: 5.0,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    if (orgPhone != null && orgPhone.trim().isNotEmpty && orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty)
                                      pw.Text('  |  ', style: pw.TextStyle(font: fontRegular, fontSize: 5.0, color: palette.textSecondary)),
                                    if (orgWhatsapp != null && orgWhatsapp.trim().isNotEmpty)
                                      _buildWhatsappSnippet(
                                        number: orgWhatsapp,
                                        waIcon: waIcon,
                                        font: fontRegular,
                                        fontSize: 5.0,
                                        color: palette.textSecondary,
                                      ),
                                  ],
                                ),
                              if (orgEmail != null || orgWebsite != null)
                                pw.Text(
                                  [
                                    if (orgEmail != null && orgEmail.trim().isNotEmpty) orgEmail,
                                    if (orgWebsite != null && orgWebsite.trim().isNotEmpty)
                                      orgWebsite.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'^www\.'), ''),
                                  ].join('  |  '),
                                  style: pw.TextStyle(
                                    font: fontRegular,
                                    fontSize: 5.0,
                                    color: palette.textSecondary,
                                  ),
                                  maxLines: 1,
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
    String? orgEmail,
    String? orgPhone,
    String? orgWhatsapp,
    String? orgWebsite,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final orgLogoImage = await _resolveImage(orgLogo);
    final partnerLogoImage = await _resolveImage(partnerLogo);

    final origin = baseUrl ?? AppConfig.baseUrl;
    final claimUrl = '$origin/p/c/${promotion.id}';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expDateStr = promotion.expirationDate != null ? dateFormat.format(promotion.expirationDate!) : null;

    final ticketBgImage = await _loadThemeBgImage(theme);

    final waIcon = await _loadWhatsappIcon();

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
                orgPhone: orgPhone,
                orgWhatsapp: orgWhatsapp,
                orgEmail: orgEmail,
                orgWebsite: orgWebsite,
                waIcon: waIcon,
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
    String? orgEmail,
    String? orgPhone,
    String? orgWhatsapp,
    String? orgWebsite,
    String? orgAddress,
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
      orgEmail: orgEmail,
      orgPhone: orgPhone,
          orgWhatsapp: orgWhatsapp,
      orgWebsite: orgWebsite,
      orgAddress: orgAddress,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdfBytes,
      name: 'Coupon_${promotion.codePrefix}_${format.name}_${theme.name}.pdf',
    );
  }

  /// Downloads a clean page with just the QR code, suitable for use in external design tools.
  static Future<void> downloadQrCode({
    required PromotionModel promotion,
    String? baseUrl,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final origin = baseUrl ?? AppConfig.baseUrl;
    final claimUrl = '$origin/p/c/${promotion.id}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  promotion.title,
                  style: pw.TextStyle(font: fontBold, fontSize: 18),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                if (promotion.codePrefix.isNotEmpty)
                  pw.Text(
                    'Codice: ${promotion.codePrefix}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 12, color: PdfColors.grey700),
                  ),
                pw.SizedBox(height: 30),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: claimUrl,
                    width: 300,
                    height: 300,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  claimUrl,
                  style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Inquadra il QR Code con la fotocamera per attivare il pass',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdfBytes,
      name: 'QRCode_${promotion.codePrefix}.pdf',
    );
  }
}
