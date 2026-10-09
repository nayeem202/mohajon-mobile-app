import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../providers/report_providers.dart';
import '../services/inventory_excel_service.dart';
import '../services/inventory_pdf_service.dart';
import 'report_shared_widgets.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen>
    with SingleTickerProviderStateMixin, ReportExportMixin {
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

  Future<void> _exportXlsx() => runExport(
        isXlsx: true,
        task: () async {
          final report = ref.read(inventoryReportProvider);
          if (report.products.isEmpty) return;
          await InventoryExcelService().saveInventoryReport(report);
        },
        message: AppLocalizations.of(context)
            .tP('exportedAsXlsx', {'report': AppLocalizations.of(context).t('reportInventory')}),
      );

  Future<void> _exportPdf() => runExport(
        isXlsx: false,
        task: () async {
          final report = ref.read(inventoryReportProvider);
          if (report.products.isEmpty) return;
          final company = await DocCompany.fromShopForExport(
            ref.read(shopProfileProvider).value,
          );
          await InventoryPdfService().saveInventoryReport(report, company);
        },
        message: AppLocalizations.of(context)
            .tP('exportedAsPdf', {'report': AppLocalizations.of(context).t('reportInventory')}),
      );

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(inventoryReportProvider);
    final l10n = AppLocalizations.of(context);
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
          title: Text(
            l10n.t('reportInventory'),
            style: const TextStyle(
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
              onRefresh: () async {
                _animCtrl.forward(from: 0);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  ReportBrandStrip(
                    title: l10n.t('reportInventory'),
                    icon: Icons.inventory_2_rounded,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ReportSummaryCard(
                          label: l10n.t('totalItems'),
                          value: '${report.totalItems}',
                          valueColor: const Color(0xFF9A3412),
                          icon: Icons.inventory_2_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCard(
                          label: l10n.t('stockValue'),
                          value: money(report.totalStockValue),
                          valueColor: MohajonWarm.goldText,
                          icon: Icons.attach_money_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ReportSummaryCard(
                          label: l10n.t('lowStockLabel'),
                          value: '${report.lowStockCount}',
                          valueColor: const Color(0xFFB45309),
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportSummaryCard(
                          label: l10n.t('outOfStockLabel'),
                          value: '${report.outOfStockCount}',
                          valueColor: const Color(0xFFB91C1C),
                          icon: Icons.block_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ReportExportButton(
                          label: l10n.t('downloadXlsx'),
                          icon: Icons.table_chart_outlined,
                          color: const Color(0xFF059669),
                          isBusy: exportingXlsx,
                          onTap: _exportXlsx,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ReportExportButton(
                          label: l10n.t('downloadPdf'),
                          icon: Icons.picture_as_pdf_rounded,
                          color: const Color(0xFFF97316),
                          isBusy: exportingPdf,
                          onTap: _exportPdf,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_showSearch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: l10n.t('searchProducts'),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: MohajonWarm.goldText,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: MohajonWarm.muted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _query = '';
                                      _searchCtrl.clear();
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFFFFDF7),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: MohajonWarm.goldBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: MohajonWarm.goldBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: MohajonWarm.orange,
                              width: 1.4,
                            ),
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
    final l10n = AppLocalizations.of(context);
    if (products.isEmpty) {
      return const _EmptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                size: 15,
                color: MohajonWarm.ink,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              l10n.t('inventoryItems'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                color: Color(0x992F3028),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MohajonWarm.tintYellow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: Text(
                l10n.tP('xItems', {'count': '${products.length}'}),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: MohajonWarm.goldText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
    final l10n = AppLocalizations.of(context);
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

    final statusLabel = status == InventoryStatus.outOfStock
        ? l10n.t('outOfStockStatus')
        : status == InventoryStatus.low
            ? l10n.t('lowStockStatus')
            : l10n.t('inStockStatus');

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
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MohajonWarm.goldBorder),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.ink.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Positioned(
                    top: -18,
                    right: -18,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: indicatorColor.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 88,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(left: 12, right: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                indicatorColor,
                                indicatorColor.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: indicatorColor.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            (product.imagePath ?? '').isNotEmpty
                                ? Icons.image_outlined
                                : Icons.inventory_2_outlined,
                            color: Colors.white,
                            size: 20,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: MohajonWarm.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.tP('stockValueOf', {
                                  'amount': money(product.purchasePrice * product.stockQty),
                                }),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: MohajonWarm.goldText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.category.isEmpty
                                    ? l10n.t('uncategorized')
                                    : product.category,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: MohajonWarm.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${product.stockQty}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: qtyColor,
                                ),
                              ),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: qtyColor.withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                l10n.tP('alertStock', {'qty': '${product.lowStockAlert}'}),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: MohajonWarm.muted,
                                ),
                              ),
                            ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MohajonWarm.tintYellow,
              border: Border.all(color: MohajonWarm.goldBorder),
            ),
            child: const Icon(
              Icons.warehouse_outlined,
              size: 40,
              color: MohajonWarm.goldText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('noInventoryFound'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('addProductsToSee'),
            style: const TextStyle(
              fontSize: 13,
              color: MohajonWarm.muted,
            ),
          ),
        ],
      ),
    );
  }
}
