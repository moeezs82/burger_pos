import 'dart:typed_data';
import 'package:counter_iq/services/thermal_printer_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class ThermalReceiptBuilder {
  ThermalReceiptBuilder._();
  static final instance = ThermalReceiptBuilder._();

  final PaperSize paperSize = PaperSize.mm80;
  static const String defaultLogoAsset = "assets/images/logo.jpeg";

  Future<List<int>> buildSaleReceiptBytes({
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
    final bytes = <int>[];

    // Logo
    final logo = await _prepareLogo(logoBytes: logoBytes, logoAsset: logoAsset);
    if (logo != null) {
      bytes.addAll(generator.imageRaster(logo, align: PosAlign.center));
      bytes.addAll(generator.feed(1));
    }

    // Header
    bytes.addAll(generator.text(
      shopName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
    ));

    if (shopAddress != null && shopAddress.trim().isNotEmpty) {
      bytes.addAll(generator.text(
        shopAddress,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    if (shopPhone != null && shopPhone.trim().isNotEmpty) {
      bytes.addAll(generator.text(
        shopPhone,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(
      "Receipt# $receiptNo",
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(generator.text(
      "Date : ${_formatDateTime(dateTime)}",
      styles: const PosStyles(align: PosAlign.center),
      linesAfter: 1,
    ));

    bytes.addAll(generator.hr());

    final hasCustomerInfo =
        cName.isNotEmpty || cPhone.isNotEmpty || cAddr.isNotEmpty;

    if (hasCustomerInfo) {
      bytes.addAll(generator.text("Customer", styles: const PosStyles(bold: true)));
      if (cName.isNotEmpty) bytes.addAll(generator.text("Name: $cName"));
      if (cPhone.isNotEmpty) bytes.addAll(generator.text("Phone: $cPhone"));
      if (cAddr.isNotEmpty) bytes.addAll(generator.text("Address: $cAddr"));
      bytes.addAll(generator.hr());
    }

    bytes.addAll(generator.row([
      PosColumn(text: "Name", width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
        text: "Price",
        width: 2,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        text: "Qty",
        width: 2,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        text: "Total",
        width: 3,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    bytes.addAll(generator.hr());

    for (final it in items) {
      bytes.addAll(generator.text(it.name, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: "", width: 5),
        PosColumn(
          text: _money(it.price),
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: _qty(it.qty),
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: _money(it.total),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(generator.hr());

    bytes.addAll(_kv(generator, "Subtotal", _money(subtotal), boldRight: true));
    if (discount > 0) {
      bytes.addAll(_kv(generator, "Discount", "-${_money(discount)}", boldRight: true));
    }
    if (tax > 0) {
      bytes.addAll(_kv(generator, "Tax", _money(tax), boldRight: true));
    }
    if (delivery > 0) {
      bytes.addAll(_kv(generator, "Delivery", _money(delivery), boldRight: true));
    }

    bytes.addAll(generator.hr());

    bytes.addAll(_kv(
      generator,
      "Grand Total",
      _money(grandTotal),
      boldLeft: true,
      boldRight: true,
      rightBig: true,
    ));

    bytes.addAll(generator.feed(1));
    bytes.addAll(_kv(generator, "Cash Received", _money(cashReceived), boldRight: true));
    bytes.addAll(_kv(generator, "Change Amount", _money(changeAmount), boldRight: true));

    bytes.addAll(generator.hr());

    bytes.addAll(generator.text(
      "Thank You, Order Again.",
      styles: const PosStyles(align: PosAlign.center, bold: true),
      linesAfter: 1,
    ));

    bytes.addAll(generator.text(
      "Powered By FriendDevelopers",
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.text(
      "03033807582",
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  Future<img.Image?> _prepareLogo({
    Uint8List? logoBytes,
    String? logoAsset,
  }) async {
    Uint8List? bytes = logoBytes;

    final effectiveAsset =
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

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = img.copyResize(decoded, width: 220);
    return img.grayscale(resized);
  }

  static List<int> _kv(
    Generator generator,
    String left,
    String right, {
    bool boldLeft = false,
    bool boldRight = false,
    bool rightBig = false,
  }) {
    return generator.row([
      PosColumn(text: left, width: 8, styles: PosStyles(bold: boldLeft)),
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
    ]);
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
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  static String _money(num v) => v.toStringAsFixed(2);
  static String _qty(num v) => (v % 1 == 0) ? v.toInt().toString() : v.toString();
}