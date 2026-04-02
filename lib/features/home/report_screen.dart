// lib/features/home/report_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';

class ReportsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final String? managerStoreId;
  const ReportsScreen({super.key, required this.isSuperAdmin, this.managerStoreId});

  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true; String? _error; Map<String, dynamic> _stats = {}; List<Map<String, dynamic>> _byService = [];

  @override void initState() { super.initState(); _loadReports(); }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from(AppConstants.ordersTable).select('status, total_price, created_at, services(title)');
      if (!widget.isSuperAdmin && widget.managerStoreId != null) {
        query = query.eq('store_id', widget.managerStoreId!);
      }

      final orders = await query;
      final all = orders as List; final delivered = all.where((o) => o['status'] == 'delivered');
      final totalRev = delivered.fold<double>(0, (s, o) => s + ((o['total_price'] as num?)?.toDouble() ?? 0));
      final totalOrders = all.length; final avgVal = totalOrders > 0 ? totalRev / totalOrders : 0;

      final now = DateTime.now(); final monthly = <String, double>{}; final monthlyCount = <String, int>{};
      for (var i = 5; i >= 0; i--) { final d = DateTime(now.year, now.month - i, 1); final key = '${_monthName(d.month)} ${d.year}'; monthly[key] = 0; monthlyCount[key] = 0; }
      for (final o in all) {
        if (o['created_at'] == null) continue;
        final d = DateTime.parse(o['created_at']); final key = '${_monthName(d.month)} ${d.year}';
        if (monthly.containsKey(key)) { monthly[key] = (monthly[key] ?? 0) + ((o['total_price'] as num?)?.toDouble() ?? 0); monthlyCount[key] = (monthlyCount[key] ?? 0) + 1; }
      }

      final svcMap = <String, int>{};
      for (final o in all) { final title = (o['services'] as Map?)?['title'] as String? ?? 'Unknown'; svcMap[title] = (svcMap[title] ?? 0) + 1; }
      final svcList = svcMap.entries.map((e) => {'title': e.key, 'count': e.value}).toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() { _stats = {'totalRevenue': totalRev, 'totalOrders': totalOrders, 'avgOrderValue': avgVal, 'deliveredCount': delivered.length, 'monthly': monthly, 'monthlyCount': monthlyCount}; _byService = svcList; _loading = false; });
    } catch (e) { setState(() { _loading = false; _error = e.toString(); }); }
  }

  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  @override Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 72, padding: const EdgeInsets.symmetric(horizontal: 32), decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Reports & Analytics', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)), Text(widget.isSuperAdmin ? 'Business performance overview' : 'Your Store Performance Overview', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext))]),
          const Spacer(), Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.text), onPressed: _loadReports)),
        ]),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(builder: (ctx, c) {
              int cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 24, mainAxisSpacing: 24, mainAxisExtent: 140), itemCount: 4, itemBuilder: (_, i) {
                final items = [('Total Revenue', '৳${(_stats['totalRevenue'] as double).toStringAsFixed(0)}', Icons.attach_money, AppColors.success), ('Total Orders', '${_stats['totalOrders']}', Icons.receipt_long_outlined, AppColors.primary), ('Avg Order Value', '৳${(_stats['avgOrderValue'] as num).toStringAsFixed(0)}', Icons.bar_chart, AppColors.info), ('Delivered', '${_stats['deliveredCount']}', Icons.check_circle_outline, AppColors.success)];
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: item.$4.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(item.$3, color: item.$4, size: 24)), const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.$1, style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 6), Text(item.$2, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text))]),
                  ]),
                );
              });
            }),
            const SizedBox(height: 32),
            _ChartCard(title: 'Monthly Revenue (৳)', color: AppColors.success, data: Map<String, double>.from(_stats['monthly'] as Map? ?? {})), const SizedBox(height: 24),
            _ChartCard(title: 'Monthly Orders', color: AppColors.primary, data: (_stats['monthlyCount'] as Map? ?? {}).map((k, v) => MapEntry(k, (v as int).toDouble())), formatValue: (v) => v.toStringAsFixed(0)), const SizedBox(height: 24),
            if (_byService.isNotEmpty) ...[
              Text('Orders by Service', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)), const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(children: _byService.map((s) {
                  final max = (_byService.first['count'] as int).toDouble(); final count = (s['count'] as int).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(s['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)), Text('${s['count']} orders', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold))]), const SizedBox(height: 8),
                      LinearProgressIndicator(value: max > 0 ? count / max : 0, minHeight: 8, backgroundColor: AppColors.background, color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    ]),
                  );
                }).toList()),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  final String title; final Color color; final Map<String, double> data; final String Function(double)? formatValue;
  const _ChartCard({required this.title, required this.color, required this.data, this.formatValue});

  @override Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink(); final maxVal = data.values.reduce(max);
    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)), const SizedBox(height: 24),
        ...data.entries.map((e) {
          final pct = maxVal > 0 ? e.value / maxVal : 0.0; final label = formatValue != null ? formatValue!(e.value) : e.value.toStringAsFixed(0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key, style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext, fontWeight: FontWeight.w500)), Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color))]), const SizedBox(height: 8),
              LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.background, color: color, borderRadius: BorderRadius.circular(8)),
            ]),
          );
        }),
      ]),
    );
  }
}