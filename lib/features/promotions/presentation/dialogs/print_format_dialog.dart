import 'package:flutter/material.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/promotions/data/promotion_pdf_service.dart';

class PrintFormatDialog extends StatefulWidget {
  final Organization org;
  final PromotionModel promo;
  final List<VoucherModel> vouchers;

  const PrintFormatDialog({
    super.key,
    required this.org,
    required this.promo,
    required this.vouchers,
  });

  @override
  State<PrintFormatDialog> createState() => _PrintFormatDialogState();
}

class _PrintFormatDialogState extends State<PrintFormatDialog> {
  CouponPrintFormat _selectedFormat = CouponPrintFormat.deskStandA4;
  CouponVisualTheme _selectedTheme = CouponVisualTheme.luxurySpa;
  bool _isGenerating = false;
  late bool _partnerLogoDarkBg;

  @override
  void initState() {
    super.initState();
    _partnerLogoDarkBg = widget.promo.partnerLogoDarkBg;
  }

  Future<void> _startPrint() async {
    setState(() => _isGenerating = true);
    try {
      await PromotionPdfService.printCoupons(
        promotion: widget.promo,
        vouchers: widget.vouchers,
        orgName: widget.org.name,
        orgLogo: widget.org.logo,
        partnerLogo: widget.promo.partnerLogoUrl,
        format: _selectedFormat,
        overridePartnerLogoDarkBg: _partnerLogoDarkBg,
        theme: _selectedTheme,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la preparazione del PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formato Stampa Coupon',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Scegli layout e tema grafico per la tua promozione',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LAYOUT DI STAMPA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...CouponPrintFormat.values.map((format) {
                      final isSelected = _selectedFormat == format;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFormat = format),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      format.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      format.description,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 14),
                    const Text(
                      'TEMA GRAFICO & COLORI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: CouponVisualTheme.values.map((theme) {
                        final isSelected = _selectedTheme == theme;
                        final (IconData icon, Color primaryCol, Color accentCol, String label) = switch (theme) {
                          CouponVisualTheme.luxurySpa => (
                            Icons.spa_rounded,
                            const Color(0xFF0F172A),
                            const Color(0xFFD97706),
                            'Luxury SPA',
                          ),
                          CouponVisualTheme.sportDynamic => (
                            Icons.fitness_center_rounded,
                            const Color(0xFF09090B),
                            const Color(0xFF84CC16),
                            'Sport Energy',
                          ),
                          CouponVisualTheme.modernMinimal => (
                            Icons.confirmation_number_rounded,
                            const Color(0xFFF1F5F9),
                            const Color(0xFF4338CA),
                            'Clean Modern',
                          ),
                        };

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTheme = theme),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: primaryCol,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.border, width: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: accentCol,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _selectedTheme.description,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),

                    if (widget.promo.partnerLogoUrl != null && widget.promo.partnerLogoUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'Sfondo scuro per logo partner',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Consigliato per loghi con scritte o dettagli bianchi/chiari per garantire contrasto',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          value: _partnerLogoDarkBg,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _partnerLogoDarkBg = val),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isGenerating ? null : () async {
                    setState(() => _isGenerating = true);
                    try {
                      await PromotionPdfService.downloadQrCode(
                        promotion: widget.promo,
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isGenerating = false);
                    }
                  },
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('Scarica QR'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _startPrint,
                  icon: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(_isGenerating ? 'Generazione...' : 'Scarica PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
