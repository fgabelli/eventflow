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
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(28),
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Scegli il layout ideale per la tua stampa',
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

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 16),

            ...CouponPrintFormat.values.map((format) {
              final isSelected = _selectedFormat == format;
              return GestureDetector(
                onTap: () => setState(() => _selectedFormat = format),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
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
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              format.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              format.description,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (widget.promo.partnerLogoUrl != null && widget.promo.partnerLogoUrl!.trim().isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Consigliato per loghi con scritte o dettagli bianchi/chiari per garantire contrasto sulla stampa',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: _partnerLogoDarkBg,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _partnerLogoDarkBg = val),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _startPrint,
                  icon: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(_isGenerating ? 'Generazione...' : 'Scarica / Stampa PDF'),
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
