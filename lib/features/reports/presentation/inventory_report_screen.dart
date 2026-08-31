import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../providers/report_providers.dart';
import '../services/inventory_excel_service.dart';
import '../services/inventory_pdf_service.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _query = '';
        _searchCtrl.clear();
      }
    });
  }

  Future<void> _exportXlsx() async {
    final report = ref.read(inventoryReportProvider);
    if (report.products.isEmpty) return;
    final service = InventoryExcelService();
    await service.saveInventoryReport(report);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inventory report exported as XLSX')),
    );
  }

  Future<void> _exportPdf() async {
    final report = ref.read(inventoryReportProvider);
    if (report.products.isEmpty) return;
    final service = InventoryPdfService();
    await service.saveInventoryReport(report);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inventory report exported as PDF')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(inventoryReportProvider);
    final products = _query.isEmpty
        ? report.products
        : report.products.where((p) {
            final q = _query.toLowerCase();
            return p.nameEn.toLowerCase().contains(q) ||
                p.nameBn.toLowerCase().contains(q) ||
                p.barcode.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q);
          }).toList();

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Inventory Report',
            style: TextStyle(
              color: MohajonWarm.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          backgroundColor: MohajonWarm.primary,
          foregroundColor: MohajonWarm.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: MohajonWarm.primary,
            statusBarIconBrightness: Brightness.dark,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              ),
              onPressed: _toggleSearch,
            ),
            const NotificationBell(),
            const SizedBox(width: 6),
            const ShopAvatar(),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: RefreshIndicator(
        onRefresh: () async => _animCtrl.forward(from: 0),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SummaryCardsRow(report: report, animCtrl: _animCtrl),
            const SizedBox(height: 16),
            _ExportButtonsRow(
              animCtrl: _animCtrl,
              onXlsxTap: _exportXlsx,
              onPdfTap: _exportPdf,
            ),
            const SizedBox(height: 20),
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _query = '';
                                _searchCtrl.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8DDD2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8DDD2)),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            _InventoryListView(
              products: products,
              animCtrl: _animCtrl,
            ),
          ],
        ),
        ),
        ),
      ),
      floatingActionButton: _FloatingSearchButton(onTap: _toggleSearch),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _ExportButtonsRow extends StatelessWidget {
  final AnimationController animCtrl;
  final VoidCallback onXlsxTap;
  final VoidCallback onPdfTap;

  const _ExportButtonsRow({
    required this.animCtrl,
    required this.onXlsxTap,
    required this.onPdfTap,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animCtrl,
        curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animCtrl,
            curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
          ),
        ),
        child: Row(
          children: [
            _ExportPill(
              label: 'XLSX',
              icon: Icons.table_chart_outlined,
              color: const Color(0xFF059669),
              onTap: onXlsxTap,
            ),
            const SizedBox(width: 10),
            _ExportPill(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFFEA580C),
              onTap: onPdfTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExportPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  final InventoryReport report;
  final AnimationController animCtrl;

  const _SummaryCardsRow({required this.report, required this.animCtrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total Items',
            value: '${report.totalItems}',
            valueColor: const Color(0xFFEA580C),
            delay: 0.0,
            animCtrl: animCtrl,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Stock Value',
            value: money(report.totalStockValue),
            valueColor: const Color(0xFF101828),
            delay: 0.1,
            animCtrl: animCtrl,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Low Stock',
            value: '${report.lowStockCount}',
            valueColor: const Color(0xFFB91C1C),
            delay: 0.2,
            animCtrl: animCtrl,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final double delay;
  final AnimationController animCtrl;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.delay,
    required this.animCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animCtrl,
        curve: Interval(delay, delay + 0.3, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animCtrl,
            curve: Interval(delay, delay + 0.3, curve: Curves.easeOut),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8DDD2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF98A2B3),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryListView extends StatelessWidget {
  final List<Product> products;
  final AnimationController animCtrl;

  const _InventoryListView({
    required this.products,
    required this.animCtrl,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _EmptyState();
    }
    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Inventory Items',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667085),
              ),
            ),
            const Spacer(),
            Text(
              '${products.length} items',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...products.asMap().entries.map((e) {
          return _InventoryItemCard(
            product: e.value,
            index: e.key,
            animCtrl: animCtrl,
          );
        }),
      ],
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final Product product;
  final int index;
  final AnimationController animCtrl;

  const _InventoryItemCard({
    required this.product,
    required this.index,
    required this.animCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final status = inventoryStatus(product);
    final indicatorColor = status == InventoryStatus.outOfStock
        ? const Color(0xFFDC2626)
        : status == InventoryStatus.low
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);

    final qtyColor = status == InventoryStatus.outOfStock
        ? const Color(0xFFDC2626)
        : status == InventoryStatus.low
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animCtrl,
        curve: Interval(0.5 + index * 0.025, 0.5 + index * 0.025 + 0.15, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animCtrl,
            curve: Interval(0.5 + index * 0.025, 0.5 + index * 0.025 + 0.15, curve: Curves.easeOut),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _CardWithRipple(
            onTap: () {},
            child: SizedBox(
              height: 88,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 56,
                    margin: const EdgeInsets.only(left: 12, right: 14),
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName('en'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stock Value: ${money(product.purchasePrice * product.stockQty)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.category.isEmpty ? 'Uncategorized' : product.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Stock: ${product.stockQty}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: qtyColor,
                          ),
                        ),
                        Text(
                          'Alert: ${product.lowStockAlert}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF98A2B3),
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
      ),
    );
  }
}

class _CardWithRipple extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _CardWithRipple({required this.child, required this.onTap});

  @override
  State<_CardWithRipple> createState() => _CardWithRippleState();
}

class _CardWithRippleState extends State<_CardWithRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      value: 1,
    );
    _scaleAnim = Tween<double>(begin: 1, end: 1.02).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8DDD2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _scaleCtrl.forward();
            Future.delayed(const Duration(milliseconds: 120), () {
              _scaleCtrl.reverse();
              widget.onTap();
            });
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No inventory found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Product'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingSearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        elevation: 4,
        color: const Color(0xFFF97316),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Icon(
            Icons.search_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
