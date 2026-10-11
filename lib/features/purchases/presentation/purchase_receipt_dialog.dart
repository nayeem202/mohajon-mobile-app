import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../models/purchase_order.dart';

class PurchaseReceiptDraft {
  const PurchaseReceiptDraft({
    required this.delivered,
    required this.damaged,
    required this.unitCosts,
    required this.issueNotes,
    required this.invoiceAmount,
    required this.invoiceNumber,
    required this.freightAmount,
    required this.discountAmount,
    required this.attachmentPath,
    required this.notes,
  });

  final Map<String, double> delivered;
  final Map<String, double> damaged;
  final Map<String, double> unitCosts;
  final Map<String, String> issueNotes;
  final double invoiceAmount;
  final String invoiceNumber;
  final double freightAmount;
  final double discountAmount;
  final String attachmentPath;
  final String notes;
}

Future<PurchaseReceiptDraft?> showPurchaseReceiptDialog(
  BuildContext context,
  PurchaseOrder order,
) => showDialog<PurchaseReceiptDraft>(
  context: context,
  builder: (_) => _PurchaseReceiptDialog(order: order),
);

class _PurchaseReceiptDialog extends StatefulWidget {
  const _PurchaseReceiptDialog({required this.order});
  final PurchaseOrder order;

  @override
  State<_PurchaseReceiptDialog> createState() => _PurchaseReceiptDialogState();
}

class _PurchaseReceiptDialogState extends State<_PurchaseReceiptDialog> {
  late final Map<String, TextEditingController> _delivered;
  late final Map<String, TextEditingController> _damaged;
  late final Map<String, TextEditingController> _unitCosts;
  late final Map<String, TextEditingController> _issueNotes;
  final _invoiceNumber = TextEditingController();
  final _invoiceAmount = TextEditingController();
  final _freight = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _picker = ImagePicker();
  String _attachmentPath = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _delivered = {
      for (final item in widget.order.items)
        item.productId: TextEditingController(
          text:
              (item.qty -
                      (widget.order.deliveredQty[item.productId] ??
                          widget.order.receivedQty[item.productId] ??
                          0))
                  .clamp(0, double.infinity)
                  .toStringAsFixed(0),
        ),
    };
    _damaged = {
      for (final item in widget.order.items)
        item.productId: TextEditingController(text: '0'),
    };
    _unitCosts = {
      for (final item in widget.order.items)
        item.productId: TextEditingController(
          text: item.unitCost.toStringAsFixed(2),
        ),
    };
    _issueNotes = {
      for (final item in widget.order.items)
        item.productId: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in [
      ..._delivered.values,
      ..._damaged.values,
      ..._unitCosts.values,
      ..._issueNotes.values,
    ]) {
      controller.dispose();
    }
    for (final controller in [
      _invoiceNumber,
      _invoiceAmount,
      _freight,
      _discount,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? double.nan;

  Future<void> _chooseAttachment(AppLocalizations l10n) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.t('takePhoto')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.t('chooseFromGallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await _pickAttachment(l10n, source);
  }

  Future<void> _pickAttachment(
    AppLocalizations l10n,
    ImageSource source,
  ) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final targetDirectory = Directory('${directory.path}/supplier_receipts');
      await targetDirectory.create(recursive: true);
      final target = File(
        '${targetDirectory.path}/receipt-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(picked.path).copy(target.path);
      if (mounted) setState(() => _attachmentPath = target.path);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.t('receiptAttachmentFailed'));
    }
  }

  double get _expectedInvoice =>
      widget.order.items.fold<double>(0, (sum, item) {
        final delivered = _value(_delivered[item.productId]!);
        final damaged = _value(_damaged[item.productId]!);
        if (!delivered.isFinite || !damaged.isFinite) return sum;
        return sum + (delivered - damaged) * item.unitCost;
      }) +
      (_value(_freight).isFinite ? _value(_freight) : 0) -
      (_value(_discount).isFinite ? _value(_discount) : 0);

  void _submit(AppLocalizations l10n) {
    final delivered = <String, double>{};
    final damaged = <String, double>{};
    final costs = <String, double>{};
    final issueNotes = <String, String>{};
    for (final item in widget.order.items) {
      final got = _value(_delivered[item.productId]!);
      final bad = _value(_damaged[item.productId]!);
      final cost = _value(_unitCosts[item.productId]!);
      final remaining =
          item.qty -
          (widget.order.deliveredQty[item.productId] ??
              widget.order.receivedQty[item.productId] ??
              0);
      if (got.isFinite &&
          bad.isFinite &&
          (got != got.floorToDouble() || bad != bad.floorToDouble())) {
        setState(() => _error = l10n.t('wholeNumbersRequired'));
        return;
      }
      if (!got.isFinite ||
          !bad.isFinite ||
          !cost.isFinite ||
          got < 0 ||
          got > remaining ||
          bad < 0 ||
          bad > got ||
          cost < 0) {
        setState(() => _error = l10n.t('receiptInvalidLine'));
        return;
      }
      delivered[item.productId] = got;
      damaged[item.productId] = bad;
      costs[item.productId] = cost;
      issueNotes[item.productId] = _issueNotes[item.productId]!.text.trim();
      if (bad > 0 && issueNotes[item.productId]!.length < 3) {
        setState(() => _error = l10n.t('damageReasonRequired'));
        return;
      }
    }
    final invoice = _value(_invoiceAmount);
    final freight = _value(_freight);
    final discount = _value(_discount);
    if (!invoice.isFinite ||
        !freight.isFinite ||
        !discount.isFinite ||
        invoice < 0 ||
        freight < 0 ||
        discount < 0 ||
        !delivered.values.any((quantity) => quantity > 0)) {
      setState(() => _error = l10n.t('receiptInvalidSummary'));
      return;
    }
    final receivedGoods = widget.order.items.fold<double>(0, (sum, item) {
      final accepted =
          (delivered[item.productId] ?? 0) - (damaged[item.productId] ?? 0);
      return sum + accepted * item.unitCost;
    });
    if (discount > receivedGoods + freight) {
      setState(() => _error = l10n.t('supplierDiscountTooHigh'));
      return;
    }
    final expected =
        widget.order.items.fold<double>(0, (sum, item) {
          final accepted =
              (delivered[item.productId] ?? 0) - (damaged[item.productId] ?? 0);
          return sum + accepted * item.unitCost;
        }) +
        freight -
        discount;
    if ((invoice - expected).abs() > 0.01 && _notes.text.trim().isEmpty) {
      setState(() => _error = l10n.t('invoiceDifferenceNoteRequired'));
      return;
    }
    Navigator.of(context).pop(
      PurchaseReceiptDraft(
        delivered: delivered,
        damaged: damaged,
        unitCosts: costs,
        issueNotes: issueNotes,
        invoiceAmount: invoice,
        invoiceNumber: _invoiceNumber.text.trim(),
        freightAmount: freight,
        discountAmount: discount,
        attachmentPath: _attachmentPath,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: (width - 32).clamp(0, 560),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * .88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogHeader(l10n),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(
                          l10n.t('receiptItemsSection'),
                          Icons.inventory_2_outlined,
                        ),
                        const SizedBox(height: 10),
                        for (final item in widget.order.items) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MohajonWarm.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MohajonWarm.goldBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  l10n.tP('orderedQtyRemaining', {
                                    'qty':
                                        '${item.qty - (widget.order.deliveredQty[item.productId] ?? widget.order.receivedQty[item.productId] ?? 0)}',
                                  }),
                                  style: const TextStyle(
                                    color: MohajonWarm.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _numberField(
                                        _delivered[item.productId]!,
                                        l10n.t('deliveredQty'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _numberField(
                                        _damaged[item.productId]!,
                                        l10n.t('damagedQty'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _numberField(
                                  _unitCosts[item.productId]!,
                                  l10n.t('actualUnitCost'),
                                ),
                                if ((_value(_damaged[item.productId]!).isFinite
                                        ? _value(_damaged[item.productId]!)
                                        : 0) >
                                    0) ...[
                                  const SizedBox(height: 6),
                                  _textField(
                                    _issueNotes[item.productId]!,
                                    l10n.t('damageReason'),
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _sectionLabel(
                          l10n.t('receiptInvoiceSection'),
                          Icons.receipt_long_outlined,
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          _invoiceNumber,
                          l10n.t('supplierInvoiceNumber'),
                        ),
                        const SizedBox(height: 8),
                        _numberField(
                          _invoiceAmount,
                          l10n.t('supplierInvoiceAmount'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(
                                _freight,
                                l10n.t('freightCost'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _numberField(
                                _discount,
                                l10n.t('supplierDiscount'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                MohajonWarm.tintGreen,
                                Color(0xFFF8FBF2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: MohajonWarm.green.withValues(alpha: .18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.fact_check_rounded,
                                    color: MohajonWarm.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      l10n.t('receiptReconciliation'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${l10n.t('expectedInvoiceTotal')}: ${_expectedInvoice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${l10n.t('supplierInvoiceVariance')}: ${((_value(_invoiceAmount).isFinite ? _value(_invoiceAmount) : 0) - _expectedInvoice).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: MohajonWarm.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _textField(_notes, l10n.t('receiptNotes'), maxLines: 2),
                        const SizedBox(height: 10),
                        _sectionLabel(
                          l10n.t('receiptAttachmentSection'),
                          Icons.attach_file_rounded,
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _chooseAttachment(l10n),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(l10n.t('attachInvoicePhoto')),
                            ),
                            if (_attachmentPath.isNotEmpty)
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_attachmentPath),
                                      width: 64,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.t('attachmentAdded'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.t('removeAttachment'),
                                    onPressed: () =>
                                        setState(() => _attachmentPath = ''),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: MohajonWarm.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: MohajonWarm.card,
                    border: Border(top: BorderSide(color: Color(0xFFF0E8D2))),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cancel = OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.t('cancel')),
                      );
                      final save = FilledButton.icon(
                        onPressed: () => _submit(l10n),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(l10n.t('receiveAndReconcile')),
                      );
                      if (constraints.maxWidth < 380) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [save, const SizedBox(height: 6), cancel],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: cancel),
                          const SizedBox(width: 10),
                          Expanded(flex: 2, child: save),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader(AppLocalizations l10n) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 17, 12, 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [MohajonWarm.tintYellow, MohajonWarm.card],
      ),
      border: Border(bottom: BorderSide(color: MohajonWarm.goldBorder)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: MohajonWarm.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.inventory_rounded, color: MohajonWarm.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('purchaseReceiptTitle'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                l10n.t('purchaseReceiptSubtitle'),
                style: const TextStyle(
                  fontSize: 12,
                  color: MohajonWarm.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.t('cancel'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  Widget _sectionLabel(String label, IconData icon) => Row(
    children: [
      Icon(icon, size: 17, color: MohajonWarm.goldText),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: MohajonWarm.ink,
          ),
        ),
      ),
    ],
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label, isDense: true),
  );
}
