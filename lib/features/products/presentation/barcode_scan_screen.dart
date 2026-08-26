import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/mohajon_warm_theme.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MohajonWarm.primary,
                          MohajonWarm.primaryPale,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: MohajonWarm.ink,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Barcode',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Find product by code',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (_done) return;
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code == null || code.isEmpty) return;
                    _done = true;
                    Navigator.of(context).pop(code);
                  },
                ),
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      children: [
                        _corner(alignment: Alignment.topLeft),
                        _corner(alignment: Alignment.topRight),
                        _corner(alignment: Alignment.bottomLeft),
                        _corner(alignment: Alignment.bottomRight),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            size: 18,
                            color: MohajonWarm.goldText,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Align the barcode inside the frame — scanning happens automatically.',
                              style: TextStyle(
                                color: MohajonWarm.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _corner({required Alignment alignment}) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: MohajonWarm.primary.withValues(alpha: 0.9),
              width: 4,
            ),
            left: BorderSide(
              color: MohajonWarm.primary.withValues(alpha: 0.9),
              width: 4,
            ),
            right: BorderSide(
              color: MohajonWarm.primary.withValues(alpha: 0.9),
              width: 4,
            ),
            bottom: BorderSide(
              color: MohajonWarm.primary.withValues(alpha: 0.9),
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(
              alignment == Alignment.topLeft ? 20 : 0,
            ),
            topRight: Radius.circular(
              alignment == Alignment.topRight ? 20 : 0,
            ),
            bottomLeft: Radius.circular(
              alignment == Alignment.bottomLeft ? 20 : 0,
            ),
            bottomRight: Radius.circular(
              alignment == Alignment.bottomRight ? 20 : 0,
            ),
          ),
        ),
      ),
    );
  }
}
