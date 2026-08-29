import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:eventflow/core/models.dart';

class BadgePrintingService {
  static Future<Uint8List> generateA4BadgeGrid(List<Attendee> attendees, EventModel event, String orgName) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    const itemsPerPage = 10;
    
    for (var i = 0; i < attendees.length; i += itemsPerPage) {
      final chunk = attendees.skip(i).take(itemsPerPage).toList();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 85 / 55, // Standard ID card ratio
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: chunk.map((attendee) => _buildBadge(attendee, event, orgName, font, fontBold)).toList(),
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  static Future<Uint8List> generateSingleLabel(Attendee attendee, EventModel event, String orgName) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final format = PdfPageFormat(90 * PdfPageFormat.mm, 54 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return _buildBadge(attendee, event, orgName, font, fontBold);
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildBadge(Attendee attendee, EventModel event, String orgName, pw.Font font, pw.Font fontBold) {
    // Try to extract company role/name if available in custom data
    String subTitle = attendee.category;
    for (final key in attendee.customData.keys) {
      if (key.toLowerCase().contains('azienda') || key.toLowerCase().contains('company')) {
        subTitle = attendee.customData[key].toString();
        break;
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
             children: [
               pw.Expanded(
                 child: pw.Text(
                   event.title,
                   style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey800),
                   maxLines: 1,
                   overflow: pw.TextOverflow.clip,
                 )
               ),
               pw.SizedBox(width: 8),
               pw.Text(
                 orgName,
                 style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
               ),
             ]
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              '${attendee.firstName}\n${attendee.lastName}',
              style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              subTitle,
              style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TICKETTO.IT',
                style: pw.TextStyle(font: fontBold, fontSize: 6, color: PdfColors.grey400),
              ),
              if (attendee.qrCode.isNotEmpty)
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: attendee.qrCode,
                  width: 30,
                  height: 30,
                  color: PdfColors.black,
                ),
            ],
          )
        ],
      ),
    );
  }

  static Future<void> printSingleLabel(Attendee attendee, EventModel event, String orgName) async {
    final pdfBytes = await generateSingleLabel(attendee, event, orgName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Badge_${attendee.firstName}_${attendee.lastName}.pdf',
    );
  }

  static Future<void> printA4Grid(List<Attendee> attendees, EventModel event, String orgName) async {
    final pdfBytes = await generateA4BadgeGrid(attendees, event, orgName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Badges_${event.title}.pdf',
    );
  }
}
