import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

class ThermalPrinterService {
  ThermalPrinterService._();
  static final instance = ThermalPrinterService._();

  final PaperSize paperSize = PaperSize.mm80;
  static const String defaultLogoAsset = "assets/images/logo.jpeg";

  Future<void> printSaleReceiptWindows({
    required String printerName,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? logoAsset,
    Uint8List? logoBytes,
    required String receiptNo,
    required DateTime dateTime,
    required List<SaleReceiptItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double cashReceived,
    required double changeAmount,
    Map<String, dynamic>? meta,
  }) async {
    if (kIsWeb || !Platform.isWindows) {
      throw Exception(
        'Windows raw printing is only supported on Windows desktop.',
      );
    }

    final bytes = await _buildSaleReceiptBytes(
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      logoAsset: logoAsset,
      logoBytes: logoBytes,
      receiptNo: receiptNo,
      dateTime: dateTime,
      items: items,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      grandTotal: grandTotal,
      cashReceived: cashReceived,
      changeAmount: changeAmount,
      meta: meta,
    );

    await _sendBytesToWindowsPrinter(
      printerName: printerName,
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<void> printSaleReceiptNetwork({
    required String printerIp,
    int port = 9100,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? logoAsset,
    Uint8List? logoBytes,
    required String receiptNo,
    required DateTime dateTime,
    required List<SaleReceiptItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double cashReceived,
    required double changeAmount,
    Map<String, dynamic>? meta,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paperSize, profile);

    final res = await printer.connect(printerIp, port: port);
    if (res != PosPrintResult.success) {
      throw Exception("Printer connect failed: ${res.msg}");
    }

    try {
      final bytes = await _buildSaleReceiptBytes(
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        logoAsset: logoAsset,
        logoBytes: logoBytes,
        receiptNo: receiptNo,
        dateTime: dateTime,
        items: items,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: grandTotal,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        meta: meta,
      );

      printer.rawBytes(bytes);
    } finally {
      printer.disconnect();
    }
  }

  Future<List<int>> _buildSaleReceiptBytes({
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? logoAsset,
    Uint8List? logoBytes,
    required String receiptNo,
    required DateTime dateTime,
    required List<SaleReceiptItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double cashReceived,
    required double changeAmount,
    Map<String, dynamic>? meta,
  }) async {
    final snapRaw = meta?["customer_snapshot"];
    final snap = (snapRaw is Map)
        ? snapRaw.cast<String, dynamic>()
        : <String, dynamic>{};

    final cName = (snap["name"] ?? "").toString().trim();
    final cPhone = (snap["phone"] ?? "").toString().trim();
    final cAddr = (snap["address"] ?? "").toString().trim();

    final delivery = (meta?["delivery"] is num)
        ? (meta!["delivery"] as num).toDouble()
        : double.tryParse((meta?["delivery"] ?? "").toString()) ?? 0.0;

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final List<int> bytes = <int>[];

    void push(List<int> chunk) {
      bytes.addAll(List<int>.from(chunk));
    }

    // TEMPORARILY DISABLED:
    // imageRaster is the part crashing in esc_pos_utils_plus
    // final logo = await _prepareLogo(
    //   logoBytes: logoBytes,
    //   logoAsset: logoAsset,
    // );
    //
    // if (logo != null) {
    //   push(generator.imageRaster(logo, align: PosAlign.center));
    //   push(generator.feed(1));
    // }

    push(
      generator.text(
        shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
        linesAfter: 1,
      ),
    );

    if (shopAddress != null && shopAddress.trim().isNotEmpty) {
      push(
        generator.text(
          shopAddress,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    if (shopPhone != null && shopPhone.trim().isNotEmpty) {
      push(
        generator.text(
          shopPhone,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    push(generator.hr());

    push(
      generator.text(
        "Receipt# $receiptNo",
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    push(
      generator.text(
        "Date : ${_formatDateTime(dateTime)}",
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 1,
      ),
    );

    push(generator.hr());

    final hasCustomerInfo =
        cName.isNotEmpty || cPhone.isNotEmpty || cAddr.isNotEmpty;

    if (hasCustomerInfo) {
      push(generator.text("Customer", styles: const PosStyles(bold: true)));
      if (cName.isNotEmpty) push(generator.text("Name: $cName"));
      if (cPhone.isNotEmpty) push(generator.text("Phone: $cPhone"));
      if (cAddr.isNotEmpty) push(generator.text("Address: $cAddr"));
      push(generator.hr());
    }

    push(
      generator.row([
        PosColumn(text: "Name", width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: "| Price",
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: "| Qty",
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: "| Total",
          width: 3,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );

    push(generator.hr());

    for (final it in items) {
      push(
        generator.row([
          PosColumn(
            text: it.name,
            width: 5,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: "| ${_money(it.price)}",
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: "| ${_qty(it.qty)}",
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: "| ${_money(it.total)}",
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );

      push(generator.feed(1));
    }

    push(generator.hr());

    push(_kv(generator, "Subtotal", _money(subtotal), boldRight: true));

    if (discount > 0) {
      push(_kv(generator, "Discount", "-${_money(discount)}", boldRight: true));
    }
    if (tax > 0) {
      push(_kv(generator, "Tax", _money(tax), boldRight: true));
    }
    if (delivery > 0) {
      push(_kv(generator, "Delivery", _money(delivery), boldRight: true));
    }

    push(generator.hr());

    push(
      _kv(
        generator,
        "Grand Total",
        _money(grandTotal),
        boldLeft: true,
        boldRight: true,
        rightBig: true,
      ),
    );

    push(generator.feed(1));

    push(
      _kv(generator, "Cash Received", _money(cashReceived), boldRight: true),
    );

    push(
      _kv(generator, "Change Amount", _money(changeAmount), boldRight: true),
    );

    push(generator.hr());

    push(
      generator.text(
        "Thank You, Order Again.",
        styles: const PosStyles(align: PosAlign.center, bold: true),
        linesAfter: 1,
      ),
    );

    push(
      generator.text(
        "Powered By FriendDevelopers",
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    push(
      generator.text(
        "03033807582",
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    push(generator.feed(2));
    push(generator.cut());

    return List<int>.from(bytes);
  }

  Future<void> _sendBytesToWindowsPrinter({
    required String printerName,
    required Uint8List bytes,
  }) async {
    final hPrinter = calloc<IntPtr>();
    final printerNamePtr = TEXT(printerName);

    try {
      final openResult = OpenPrinter(printerNamePtr, hPrinter, nullptr);
      if (openResult == 0) {
        throw Exception('Failed to open printer: $printerName');
      }

      final docInfo = calloc<DOC_INFO_1>()
        ..ref.pDocName = TEXT('POS Receipt')
        ..ref.pOutputFile = nullptr
        ..ref.pDatatype = TEXT('RAW');

      try {
        if (StartDocPrinter(hPrinter.value, 1, docInfo.cast()) == 0) {
          throw Exception('StartDocPrinter failed');
        }

        if (StartPagePrinter(hPrinter.value) == 0) {
          throw Exception('StartPagePrinter failed');
        }

        final dataPtr = calloc<Uint8>(bytes.length);
        final writtenPtr = calloc<Uint32>();

        try {
          for (var i = 0; i < bytes.length; i++) {
            dataPtr[i] = bytes[i];
          }

          final ok = WritePrinter(
            hPrinter.value,
            dataPtr.cast(),
            bytes.length,
            writtenPtr,
          );

          if (ok == 0) {
            throw Exception('WritePrinter failed');
          }

          if (writtenPtr.value != bytes.length) {
            throw Exception(
              'WritePrinter wrote ${writtenPtr.value} bytes out of ${bytes.length}',
            );
          }
        } finally {
          calloc.free(dataPtr);
          calloc.free(writtenPtr);
        }

        EndPagePrinter(hPrinter.value);
        EndDocPrinter(hPrinter.value);
      } finally {
        free(docInfo.ref.pDocName);
        free(docInfo.ref.pDatatype);
        calloc.free(docInfo);
      }

      ClosePrinter(hPrinter.value);
    } finally {
      free(printerNamePtr);
      calloc.free(hPrinter);
    }
  }

  Future<img.Image?> _prepareLogo({
    Uint8List? logoBytes,
    String? logoAsset,
  }) async {
    Uint8List? bytes = logoBytes;

    final String effectiveAsset =
        (logoAsset != null && logoAsset.trim().isNotEmpty)
        ? logoAsset
        : defaultLogoAsset;

    if (bytes == null) {
      try {
        final bd = await rootBundle.load(effectiveAsset);
        bytes = bd.buffer.asUint8List();
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null) return null;

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final resized = img.copyResize(decoded, width: 220);
      return img.grayscale(resized);
    } catch (_) {
      return null;
    }
  }

  static List<int> _kv(
    Generator generator,
    String left,
    String right, {
    bool boldLeft = false,
    bool boldRight = false,
    bool rightBig = false,
  }) {
    return List<int>.from(
      generator.row([
        PosColumn(
          text: left,
          width: 8,
          styles: PosStyles(bold: boldLeft),
        ),
        PosColumn(
          text: right,
          width: 4,
          styles: PosStyles(
            align: PosAlign.right,
            bold: boldRight,
            height: rightBig ? PosTextSize.size2 : PosTextSize.size1,
            width: rightBig ? PosTextSize.size2 : PosTextSize.size1,
          ),
        ),
      ]),
    );
  }

  static String _fitText(String text, int maxChars) {
    final value = text.trim();
    if (value.length <= maxChars) return value;
    return value.substring(0, maxChars - 1) + '.';
  }

  static String _formatDateTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    final mm = dt.minute.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = _monthShort(dt.month);
    return "$dd $mo ${dt.year} - $h:$mm $ampm";
  }

  static String _monthShort(int m) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  static String _money(num v) => v.toStringAsFixed(2);

  static String _qty(num v) {
    return (v % 1 == 0) ? v.toInt().toString() : v.toString();
  }
}

class SaleReceiptItem {
  final String name;
  final double price;
  final double qty;
  final double total;

  SaleReceiptItem({
    required this.name,
    required this.price,
    required this.qty,
    required this.total,
  });
}
