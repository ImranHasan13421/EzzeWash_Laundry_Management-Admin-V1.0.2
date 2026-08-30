// lib/features/home/order_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui'; // For glassmorphism blur
import '../../core/constants/app_constants.dart';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';

// --- DYNAMIC THEME HELPERS (Glassmorphism) ---
bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
Color _surfaceColor(BuildContext context) => _isDark(context) ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.85);
Color _textColor(BuildContext context) => _isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
Color _subtextColor(BuildContext context) => _isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _borderColor(BuildContext context) => _isDark(context) ? const Color(0xFF475569).withOpacity(0.5) : const Color(0xFFE2E8F0).withOpacity(0.6);
Color _inputFillColor(BuildContext context) => _isDark(context) ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC).withOpacity(0.5);

class OrderScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final String? managerStoreId;
  const OrderScreen({super.key, required this.isSuperAdmin, this.managerStoreId});

  @override State<OrderScreen> createState() => OrderScreenState();
}

class OrderScreenState extends State<OrderScreen> {
  bool _loading = true; String? _error;
  List<Map<String, dynamic>> _allOrders = []; List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _storeOptions = []; List<Map<String, dynamic>> _serviceOptions = [];
  String _statusFilter = 'All'; String _searchQuery = ''; String _sortOption = 'Newest First';
  String _storeFilter = 'All'; String _serviceFilter = 'All'; String _scheduleFilter = 'All'; // Schedule Filter
  RealtimeChannel? _channel;

  final _statuses = ['All', 'pending', 'confirmed', 'assign_pickup', 'picked_up', 'dropped', 'received', 'in_process', 'ready', 'out_for_delivery', 'delivered', 'cancelled'];

  @override void initState() { super.initState(); _loadInitialData(); _subscribeRealtime(); }
  @override void dispose() { _channel?.unsubscribe(); super.dispose(); }

  void setStatusFilter(String targetStatus) {
    if (_statuses.contains(targetStatus)) {
      setState(() {
        _statusFilter = targetStatus;
        _applyFilter();
      });
    }
  }

  void openAddOrderDialog([Map<String, dynamic>? existingOrder]) => _showAddDialog(existingOrder);

  void _subscribeRealtime() {
    PostgresChangeFilter? orderFilter;
    if (!widget.isSuperAdmin && widget.managerStoreId != null) {
      orderFilter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'store_id', value: widget.managerStoreId!);
    }
    _channel = supabase.channel('admin_orders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AppConstants.ordersTable, filter: orderFilter, callback: (_) => _loadOrders()).subscribe();
  }

  Future<void> _loadInitialData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final storeData = await supabase.from(AppConstants.storesTable).select('id, name');
      final serviceData = await supabase.from(AppConstants.servicesTable).select('id, title');

      var query = supabase.from(AppConstants.ordersTable).select('*, profiles(full_name, phone), services(title), stores(name), pickup_rider:riders!pickup_rider_id(full_name, avatar_url), delivery_rider:riders!delivery_rider_id(full_name, avatar_url)');
      if (!widget.isSuperAdmin && widget.managerStoreId != null) query = query.eq('store_id', widget.managerStoreId!);

      final ordersData = await query.order('created_at', ascending: false);

      if (mounted) { setState(() { _storeOptions = List<Map<String, dynamic>>.from(storeData); _serviceOptions = List<Map<String, dynamic>>.from(serviceData); _allOrders = List<Map<String, dynamic>>.from(ordersData); _applyFilter(); _loading = false; }); }
    } catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<void> _loadOrders() async {
    try {
      var query = supabase.from(AppConstants.ordersTable).select('*, profiles(full_name, phone), services(title), stores(name), pickup_rider:riders!pickup_rider_id(full_name, avatar_url), delivery_rider:riders!delivery_rider_id(full_name, avatar_url)');
      if (!widget.isSuperAdmin && widget.managerStoreId != null) query = query.eq('store_id', widget.managerStoreId!);
      final data = await query.order('created_at', ascending: false);
      if (mounted) { setState(() { _allOrders = List<Map<String, dynamic>>.from(data); _applyFilter(); _loading = false; }); }
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  // --- UPDATED: Helper for Schedule Filtering (Now maps Tomorrow and beyond to 'Advance Booking') ---
  String _getScheduleCategory(String? rawDate) {
    if (rawDate == null) return 'None';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return 'None';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);

    if (target == today) return 'Today';
    if (target.isAfter(today)) return 'Advance Booking'; // Covers Tomorrow and any future date
    if (target.isBefore(today)) return 'Overdue';
    return 'None';
  }

  void _applyFilter() {
    _filtered = _allOrders.where((o) {
      final matchStatus = _statusFilter == 'All' || o['status'] == _statusFilter;
      final matchStore  = (!widget.isSuperAdmin) || _storeFilter == 'All' || o['store_id'].toString() == _storeFilter;
      final matchService = _serviceFilter == 'All' || o['service_id'].toString() == _serviceFilter;
      final matchSchedule = _scheduleFilter == 'All' || _getScheduleCategory(o['pickup_date']) == _scheduleFilter;
      final q = _searchQuery.toLowerCase();
      final profileName = ((o['profiles'] as Map?)?['full_name'] ?? '').toString().toLowerCase();
      final manualName = (o['manual_customer_name'] ?? '').toString().toLowerCase();
      final orderNum = (o['order_number'] ?? '').toString().toLowerCase();
      final serviceTitle = ((o['services'] as Map?)?['title'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || orderNum.contains(q) || profileName.contains(q) || manualName.contains(q) || serviceTitle.contains(q);
      return matchStatus && matchSearch && matchStore && matchService && matchSchedule;
    }).toList();
    if (_sortOption == 'Newest First') _filtered.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    else _filtered.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
  }

  double _getProgressForStatus(String status) { switch (status) { case 'pending': return 0.1; case 'confirmed': return 0.2; case 'assign_pickup': return 0.3; case 'picked_up': return 0.4; case 'dropped': return 0.5; case 'received': return 0.6; case 'in_process': return 0.7; case 'ready': return 0.8; case 'out_for_delivery': return 0.9; case 'delivered': return 1.0; default: return 0.0; } }

  String? _getNextBulkStatus(String current) { if (current == 'pending') return 'confirmed'; if (current == 'dropped') return 'received'; if (current == 'received') return 'in_process'; if (current == 'in_process') return 'ready'; return null; }
  String _getBulkActionLabel() { if (_statusFilter == 'pending') return 'Confirm All'; if (_statusFilter == 'dropped') return 'Receive All'; if (_statusFilter == 'received') return 'Start Washing All'; if (_statusFilter == 'in_process') return 'Mark All Ready'; return 'Mark All'; }

  Future<void> _handleBulkAction() async {
    if (_filtered.isEmpty) return;
    setState(() => _loading = true);
    try {
      for (var order in _filtered) { final next = _getNextBulkStatus(order['status']); if (next != null) await supabase.from(AppConstants.ordersTable).update({'status': next, 'progress': _getProgressForStatus(next)}).eq('id', order['id']); }
      await _loadOrders();
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _loading = true);
    try { await supabase.from(AppConstants.ordersTable).update({'status': newStatus, 'progress': _getProgressForStatus(newStatus), 'updated_at': DateTime.now().toIso8601String()}).eq('id', orderId); await _loadOrders(); }
    catch (e) { if (mounted) { setState(() => _loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error)); } }
  }

  Future<void> _assignRiderAndStatus(String orderId, String riderId, String nextStatus) async {
    setState(() => _loading = true);
    try {
      final riderField = nextStatus == 'assign_pickup' ? 'pickup_rider_id' : 'delivery_rider_id';
      await supabase.from(AppConstants.ordersTable).update({
        'status': nextStatus,
        riderField: riderId,
        'progress': _getProgressForStatus(nextStatus),
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', orderId);
      await _loadOrders();
    }
    catch (e) { if (mounted) setState(() => _loading = false); }
  }

  // --- UPDATED: Branch-segregated & sorted rider assignment modal ---
  Future<void> _showRiderSelection(Map<String, dynamic> order, String nextStatus) async {
    final orderId = order['id'];
    final orderStoreId = order['store_id']?.toString();

    var query = supabase.from(AppConstants.ridersTable).select('*, stores(name)').eq('is_active', true);

    // If manager is logged in, restrict riders to their branch only
    if (!widget.isSuperAdmin && widget.managerStoreId != null) {
      query = query.eq('store_id', widget.managerStoreId!);
    }

    final res = await query;
    List<Map<String, dynamic>> availableRiders = List<Map<String, dynamic>>.from(res);

    // If Super Admin is logged in, prioritize/sort riders belonging to this order's store branch to the top
    if (widget.isSuperAdmin && orderStoreId != null) {
      availableRiders.sort((a, b) {
        bool aMatches = a['store_id']?.toString() == orderStoreId;
        bool bMatches = b['store_id']?.toString() == orderStoreId;
        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;
        return 0;
      });
    }

    if (!mounted) return;
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            backgroundColor: _surfaceColor(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))),
            title: Text(nextStatus == 'assign_pickup' ? 'Dispatch for Pickup' : 'Dispatch for Delivery', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: _textColor(context))),
            content: SizedBox(
                width: 440,
                child: availableRiders.isEmpty
                    ? Padding(padding: const EdgeInsets.all(24), child: Text("No active riders available for this branch.", style: GoogleFonts.inter(color: _subtextColor(context))))
                    : ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableRiders.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)),
                    itemBuilder: (c, i) {
                      final r = availableRiders[i];
                      final isOnline = r['is_online'] == true;
                      final avatar = r['avatar_url'] as String?;
                      final storeName = r['stores']?['name'] ?? 'Unassigned Branch';
                      final isMatchingBranch = orderStoreId != null && r['store_id']?.toString() == orderStoreId;

                      return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                              child: (avatar == null || avatar.isEmpty) ? Text(r['full_name'][0].toUpperCase(), style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)) : null
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(r['full_name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context)))),
                              if (widget.isSuperAdmin && isMatchingBranch)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text('MATCHING BRANCH', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                )
                            ],
                          ),
                          subtitle: Text('${r['vehicle_type'].toString().toUpperCase()} • $storeName', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context))),
                          trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: (isOnline ? AppColors.success : Colors.grey.shade400).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.inter(fontSize: 11, color: isOnline ? AppColors.success : Colors.grey.shade600, fontWeight: FontWeight.bold))
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _assignRiderAndStatus(orderId, r['id'], nextStatus);
                          }
                      );
                    }
                )
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context), fontWeight: FontWeight.w600))
              )
            ]
        )
    );
  }

  Future<void> _handleActionClick(Map<String, dynamic> order) async {
    final orderId = order['id'];
    final currentStatus = order['status'] ?? 'pending';
    final logisticsMode = order['logistics_mode'] ?? 'full_service';

    if (currentStatus == 'pending') {
      _updateStatus(orderId, 'confirmed');
    }
    else if (currentStatus == 'confirmed') {
      if (logisticsMode == 'self_service' || logisticsMode == 'delivery_only') {
        _updateStatus(orderId, 'received');
      } else {
        _showRiderSelection(order, 'assign_pickup');
      }
    }
    else if (currentStatus == 'dropped') { _updateStatus(orderId, 'received'); }
    else if (currentStatus == 'received') { _updateStatus(orderId, 'in_process'); }
    else if (currentStatus == 'in_process') { _updateStatus(orderId, 'ready'); }
    else if (currentStatus == 'ready') {
      if (logisticsMode == 'self_service') {
        _updateStatus(orderId, 'delivered');
      } else {
        _showRiderSelection(order, 'out_for_delivery');
      }
    }
  }

  Widget _buildDeliveredSplitView() {
    final homeDeliveries = _filtered.where((o) => o['logistics_mode'] != 'self_service').toList();
    final inStorePickups = _filtered.where((o) => o['logistics_mode'] == 'self_service').toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildSplitColumn('Home Deliveries', 'Completed by Riders', Icons.local_shipping_outlined, AppColors.primary, homeDeliveries)),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildSplitColumn('In-Store Pickups', 'Handed over at counter', Icons.storefront_outlined, AppColors.success, inStorePickups)),
      ],
    );
  }

  Widget _buildSplitColumn(String title, String subtitle, IconData icon, Color color, List<Map<String, dynamic>> columnOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
          child: Row(children: [
            Icon(icon, color: color, size: 20), const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textColor(context))), Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _subtextColor(context)))]),
            const Spacer(),
            CircleAvatar(radius: 12, backgroundColor: color, child: Text('${columnOrders.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
          ]),
        ),
        const SizedBox(height: 16),
        if (columnOrders.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No orders', style: TextStyle(color: _subtextColor(context)))))
        else ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: columnOrders.length, separatorBuilder: (_, __) => const SizedBox(height: 16), itemBuilder: (_, i) => _OrderCard(order: columnOrders[i], onActionClick: () => _handleActionClick(columnOrders[i]), onCancelClick: () => _updateStatus(columnOrders[i]['id'], 'cancelled'), onEditClick: () => openAddOrderDialog(columnOrders[i]), onPrintClick: () => _generateAndPrintReceipt(columnOrders[i]))),
      ],
    );
  }

  @override Widget build(BuildContext context) {
    return Column(children: [
      ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 72, padding: const EdgeInsets.symmetric(horizontal: 32), decoration: BoxDecoration(color: _surfaceColor(context), border: Border(bottom: BorderSide(color: _borderColor(context)))),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Orders', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: _textColor(context))), Text('Direct business operations management', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context)))]),
              const Spacer(),
              Container(decoration: BoxDecoration(color: _inputFillColor(context), borderRadius: BorderRadius.circular(10)), child: IconButton(icon: Icon(Icons.refresh_rounded, color: _textColor(context)), onPressed: _loadInitialData)),
              const SizedBox(width: 16),
              _GradientButton(label: 'Add Order', icon: Icons.add, onPressed: () => openAddOrderDialog()),
            ]),
          ),
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: TextField(onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }), style: GoogleFonts.inter(fontSize: 15, color: _textColor(context)), decoration: InputDecoration(hintText: 'Search by order #, customer, service…', hintStyle: GoogleFonts.inter(color: _subtextColor(context).withOpacity(0.6), fontSize: 14), prefixIcon: Icon(Icons.search, color: _subtextColor(context), size: 22), filled: true, fillColor: _inputFillColor(context), contentPadding: const EdgeInsets.symmetric(vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor(context))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _borderColor(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary))))),
              const SizedBox(width: 16),

              if (widget.isSuperAdmin) ...[
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor(context))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: _surfaceColor(context), value: _storeFilter, items: [DropdownMenuItem(value: 'All', child: Text('All Stores', style: TextStyle(fontSize: 14, color: _textColor(context)))), ..._storeOptions.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'], style: TextStyle(fontSize: 14, color: _textColor(context)))))], onChanged: (v) => setState(() { _storeFilter = v!; _applyFilter(); })))),
                const SizedBox(width: 16),
              ],

              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor(context))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: _surfaceColor(context), value: _serviceFilter, items: [ DropdownMenuItem(value: 'All', child: Text('All Services', style: TextStyle(fontSize: 14, color: _textColor(context)))), ..._serviceOptions.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['title'], style: TextStyle(fontSize: 14, color: _textColor(context)))))], onChanged: (v) => setState(() { _serviceFilter = v!; _applyFilter(); })))),
              const SizedBox(width: 16),

              // --- UPDATED: SCHEDULE FILTER DROPDOWN (Now Uses 'Advance Booking') ---
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor(context))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: _surfaceColor(context), value: _scheduleFilter, items: ['All', 'Today', 'Advance Booking', 'Overdue'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Schedules' : s, style: TextStyle(fontSize: 14, color: _textColor(context))))).toList(), onChanged: (v) => setState(() { _scheduleFilter = v!; _applyFilter(); })))),
              const SizedBox(width: 16),

              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor(context))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: _surfaceColor(context), value: _sortOption, items: ['Newest First', 'Oldest First'].map((s) => DropdownMenuItem(value: s, child: Text(s, style:TextStyle(fontSize: 14,color: _textColor(context))))).toList(), onChanged: (v) => setState(() { _sortOption = v!; _applyFilter(); })))),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _statuses.map((s) {
                final selected = _statusFilter == s;
                return Padding(padding: const EdgeInsets.only(right: 12), child: GestureDetector(onTap: () => setState(() { _statusFilter = s; _applyFilter(); }), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: selected ? AppColors.primary : _surfaceColor(context), borderRadius: BorderRadius.circular(24), border: selected ? null : Border.all(color: _borderColor(context)), boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Text(s == 'All' ? 'All' : s.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(color: selected ? Colors.white : _subtextColor(context), fontWeight: FontWeight.bold, fontSize: 12)))));
              }).toList()))),
              if (_statusFilter != 'All' && _getNextBulkStatus(_statusFilter) != null) Padding(padding: const EdgeInsets.only(left: 16), child: ElevatedButton.icon(onPressed: _filtered.isEmpty ? null : _handleBulkAction, icon: const Icon(Icons.done_all, size: 18), label: Text(_getBulkActionLabel(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
            const SizedBox(height: 24),
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(child: Text('Error: $_error', style: GoogleFonts.inter(color: AppColors.error)))
                : _filtered.isEmpty
                ? Center(child: Text('No orders found', style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 16)))
                : _statusFilter == 'delivered'
                ? SingleChildScrollView(physics: const BouncingScrollPhysics(), child: _buildDeliveredSplitView())
                : ListView.separated(physics: const BouncingScrollPhysics(), itemCount: _filtered.length, separatorBuilder: (_, __) => const SizedBox(height: 16), itemBuilder: (_, i) => _OrderCard(order: _filtered[i], onActionClick: () => _handleActionClick(_filtered[i]), onCancelClick: () => _updateStatus(_filtered[i]['id'], 'cancelled'), onEditClick: () => openAddOrderDialog(_filtered[i]), onPrintClick: () => _generateAndPrintReceipt(_filtered[i])))),
          ]),
        ),
      ),
    ]);
  }

  void _showAddDialog(Map<String, dynamic>? order) => showDialog(context: context, builder: (_) => _AddOrderDialog(existingOrder: order, onAdded: _loadInitialData, isSuperAdmin: widget.isSuperAdmin, managerStoreId: widget.managerStoreId, onPrint: _generateAndPrintReceipt));

  Future<void> _generateAndPrintReceipt(Map<String, dynamic> order) async {
    final pdf = pw.Document();
    final isManual = order['is_manual'] == true;
    final customerName = isManual ? order['manual_customer_name'] : order['profiles']?['full_name'] ?? 'Guest';
    final customerPhone = isManual ? order['manual_customer_phone'] : order['profiles']?['phone'] ?? 'N/A';
    final service = order['services']?['title'] ?? 'Laundry Service';
    final storeName = order['stores']?['name'] ?? 'EzeeWash';
    final qty = order['item_count'] ?? 1;
    final price = (order['total_price'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('EZEEWASH', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(storeName, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 10),
                pw.Text('--------------------------------'),
                pw.SizedBox(height: 10),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Order:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('#${order['order_number']}')]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Date:'), pw.Text(DateTime.now().toString().substring(0, 10))]),
                pw.SizedBox(height: 10),
                pw.Text('--------------------------------'),
                pw.SizedBox(height: 10),
                pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('Customer: $customerName')),
                pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('Phone: $customerPhone')),
                pw.SizedBox(height: 10),
                pw.Text('--------------------------------'),
                pw.SizedBox(height: 10),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Service', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                pw.SizedBox(height: 5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('$qty x $service'), pw.Text('BDT ${price.toStringAsFixed(0)}')]),
                pw.SizedBox(height: 15),
                pw.Text('--------------------------------'),
                pw.SizedBox(height: 5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), pw.Text('BDT ${price.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: order['order_number'], width: 150, height: 40),
                pw.SizedBox(height: 10),
                pw.Text('Thank you for choosing EzeeWash!', style: const pw.TextStyle(fontSize: 10)),
              ]
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Receipt_${order['order_number']}.pdf');
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order; final VoidCallback onActionClick; final VoidCallback onCancelClick;
  final VoidCallback onEditClick; final VoidCallback onPrintClick;
  const _OrderCard({required this.order, required this.onActionClick, required this.onCancelClick, required this.onEditClick, required this.onPrintClick});

  Color _statusColor(String s) { switch (s) { case 'pending': return AppColors.warning; case 'confirmed': return Colors.teal; case 'assign_pickup': return Colors.indigo; case 'picked_up': return const Color(0xFF8B5CF6); case 'dropped': return Colors.orange; case 'received': return Colors.deepOrange; case 'in_process': return Colors.blue; case 'ready': return Colors.greenAccent.shade700; case 'out_for_delivery': return AppColors.primary; case 'delivered': return AppColors.success; case 'cancelled': return AppColors.error; default: return const Color(0xFF94A3B8); } }

  String _actionLabel(String s, String? mode) {
    if (s == 'pending') return 'Confirm Order';
    if (s == 'confirmed') return (mode == 'self_service' || mode == 'delivery_only') ? 'Mark as Received' : 'Assign Pickup Rider';
    if (s == 'dropped') return 'Mark as Received';
    if (s == 'received') return 'Start Washing';
    if (s == 'in_process') return 'Mark Ready';
    if (s == 'ready') return mode == 'self_service' ? 'Handover to Customer' : 'Assign Delivery Rider';
    return '';
  }

  Color _btnColor(String s, String? mode) {
    if (s == 'pending' || s == 'confirmed') return AppColors.primary;
    if (s == 'ready') return mode == 'self_service' ? AppColors.success : AppColors.primary;
    if (s == 'dropped') return Colors.orange;
    if (s == 'received' || s == 'in_process') return Colors.blue;
    return AppColors.success;
  }

  @override Widget build(BuildContext context) {
    final isManual = order['is_manual'] == true;
    final manualName = order['manual_customer_name'] as String?;
    final profileName = (order['profiles'] as Map?)?['full_name'] as String?;
    final String displayName = isManual ? (manualName ?? 'Manual Customer') : (profileName ?? 'Guest Customer');

    final status = order['status'] as String? ?? 'pending';
    final logisticsMode = order['logistics_mode'] as String? ?? 'full_service';
    final actionLbl = _actionLabel(status, logisticsMode);

    final pickupRider = order['pickup_rider'] as Map?;
    final deliveryRider = order['delivery_rider'] as Map?;
    Map? activeRider; String riderRole = '';

    if (['assign_pickup', 'picked_up', 'dropped'].contains(status)) { activeRider = pickupRider; riderRole = 'Pickup Rider'; }
    else if (['out_for_delivery', 'delivered'].contains(status)) { activeRider = deliveryRider; riderRole = 'Delivery Rider'; }

    // --- UPDATED: SCHEDULE BADGE LOGIC (Explicit 'Tomorrow' vs 'Advance') ---
    final String? rawDate = order['pickup_date'];
    final String? rawTime = order['pickup_time'] ?? 'Anytime';

    String scheduleLabel = 'Schedule pending';
    Color scheduleColor = Colors.grey;
    IconData scheduleIcon = Icons.calendar_today_rounded;

    if (rawDate != null) {
      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final targetDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

        if (targetDate == today) {
          scheduleLabel = 'Today, $rawTime';
          scheduleColor = Colors.green.shade600;
          scheduleIcon = Icons.directions_bike_rounded;
        } else if (targetDate == tomorrow) {
          scheduleLabel = 'Tomorrow, $rawTime';
          scheduleColor = Colors.orange.shade600;
          scheduleIcon = Icons.update_rounded;
        } else if (targetDate.isAfter(tomorrow)) {
          // Format as DD-MM-YYYY for clarity
          final formattedDate = '${parsedDate.day.toString().padLeft(2, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.year}';
          scheduleLabel = 'Advance ($formattedDate), $rawTime';
          scheduleColor = Colors.deepOrange;
          scheduleIcon = Icons.event_rounded;
        } else {
          final daysOverdue = today.difference(targetDate).inDays;
          final formattedDate = '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
          scheduleLabel = 'Overdue: $formattedDate ($daysOverdue day${daysOverdue > 1 ? 's' : ''})';
          scheduleColor = Colors.red;
          scheduleIcon = Icons.warning_rounded;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: _borderColor(context)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _inputFillColor(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor(context))), child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#${order['order_number']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor(context))),
              const SizedBox(width: 12), _badge(status, _statusColor(status)),
              if (isManual) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _inputFillColor(context), borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor(context))), child: Row(children: [Icon(Icons.edit_note, size: 12, color: Colors.blueGrey.shade700), const SizedBox(width: 4), Text('ADMIN ADDED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700))])),
                const SizedBox(width: 8),
                InkWell(onTap: onEditClick, child: Icon(Icons.edit_outlined, size: 18, color: _subtextColor(context))),
                const SizedBox(width: 8),
                InkWell(onTap: onPrintClick, child: Icon(Icons.print_outlined, size: 18, color: AppColors.primary)),
              ]
            ]),
            const SizedBox(height: 4), Text(displayName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _textColor(context))),

            // --- THE SCHEDULED TIME BADGE ---
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheduleColor.withOpacity(0.1), // Soft background based on day
                border: Border.all(color: scheduleColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Keeps the badge snug to the text
                children: [
                  Icon(scheduleIcon, size: 14, color: scheduleColor),
                  const SizedBox(width: 6),
                  Text(
                    scheduleLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheduleColor,
                    ),
                  ),
                ],
              ),
            ),

            if (activeRider != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.delivery_dining, size: 16, color: AppColors.success), const SizedBox(width: 6), Text('$riderRole: ${activeRider['full_name']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600))]))
          ])),
          Text('৳${((order['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primary)),
        ]),
        if (actionLbl.isNotEmpty) ...[
          const SizedBox(height: 20), Divider(height: 1, color: _borderColor(context)), const SizedBox(height: 16),
          Row(children: [
            _btn(actionLbl, _btnColor(status, logisticsMode), onActionClick, true),
            const SizedBox(width: 12),
            if (status == 'pending') _btn('Cancel', AppColors.error, onCancelClick, false),
          ]),
        ],
      ]),
    );
  }
  Widget _badge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(t.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(color: c, fontSize: 11, fontWeight: FontWeight.bold)));
  Widget _btn(String l, Color c, VoidCallback p, bool icon) => ElevatedButton.icon(onPressed: p, icon: icon ? const Icon(Icons.arrow_forward_rounded, size: 18) : const SizedBox.shrink(), label: Text(l, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
}

// --- ADVANCED MANUAL ORDER DIALOG ---
class _AddOrderDialog extends StatefulWidget {
  final Map<String, dynamic>? existingOrder;
  final VoidCallback onAdded;
  final bool isSuperAdmin;
  final String? managerStoreId;
  final Function(Map<String, dynamic>) onPrint;
  const _AddOrderDialog({this.existingOrder, required this.onAdded, required this.isSuperAdmin, this.managerStoreId, required this.onPrint});
  @override State<_AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<_AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _pickupAddrCtrl;
  late TextEditingController _deliveryAddrCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;

  bool _loading = false; bool _sameAsPickup = false;
  List<Map<String, dynamic>> _services = []; List<Map<String, dynamic>> _stores = [];
  String? _selectedServiceId; String? _selectedStoreId; String _logisticsMode = 'full_service';
  DateTime _pickupDate = DateTime.now(); DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));

  @override void initState() {
    super.initState();
    final o = widget.existingOrder;

    _nameCtrl = TextEditingController(text: o?['manual_customer_name']?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: o?['manual_customer_phone']?.toString() ?? '');
    _pickupAddrCtrl = TextEditingController(text: o?['pickup_address']?.toString() ?? '');
    _deliveryAddrCtrl = TextEditingController(text: o?['delivery_address']?.toString() ?? '');
    _qtyCtrl = TextEditingController(text: (o?['item_count'] ?? 1).toString());
    _priceCtrl = TextEditingController(text: ((o?['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));

    if (o != null) {
      _logisticsMode = o['logistics_mode'] ?? 'full_service';
      if (o['pickup_date'] != null) _pickupDate = DateTime.parse(o['pickup_date']);
      if (o['delivery_date'] != null) _deliveryDate = DateTime.parse(o['delivery_date']);
    }

    _loadOptions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pickupAddrCtrl.dispose();
    _deliveryAddrCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final svc = await supabase.from(AppConstants.servicesTable).select('id, title, price').eq('is_active', true);
    if (widget.isSuperAdmin) {
      final str = await supabase.from(AppConstants.storesTable).select('id, name');
      _stores = List<Map<String, dynamic>>.from(str);
    } else {
      _selectedStoreId = widget.managerStoreId;
    }

    if (mounted) setState(() {
      _services = List<Map<String, dynamic>>.from(svc);

      if (widget.existingOrder != null) {
        final o = widget.existingOrder!;
        if (o['service_id'] != null && _services.any((s) => s['id'] == o['service_id'])) {
          _selectedServiceId = o['service_id'];
        }
        if (o['store_id'] != null && _stores.any((s) => s['id'] == o['store_id'])) {
          _selectedStoreId = o['store_id'];
        }
      } else if (_services.isNotEmpty) {
        _selectedServiceId = _services.first['id'];
      }
    });

    if (widget.existingOrder == null) {
      _calculatePrice();
    }
  }

  void _calculatePrice() {
    if (_selectedServiceId == null) return;
    final svc = _services.firstWhere((s) => s['id'] == _selectedServiceId, orElse: () => <String, dynamic>{});
    if (svc.isEmpty) return;

    final basePrice = (svc['price'] as num?)?.toDouble() ?? 0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    final calculatedStr = (basePrice * qty).toStringAsFixed(0);

    if (_priceCtrl.text != calculatedStr) {
      _priceCtrl.text = calculatedStr;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final isEdit = widget.existingOrder != null;
      final payload = {
        'service_id': _selectedServiceId, 'store_id': _selectedStoreId,
        'logistics_mode': _logisticsMode, 'total_price': double.parse(_priceCtrl.text), 'item_count': int.parse(_qtyCtrl.text),
        'pickup_address': _logisticsMode == 'self_service' ? null : _pickupAddrCtrl.text.trim(),
        'delivery_address': _logisticsMode == 'self_service' ? null : _deliveryAddrCtrl.text.trim(),
        'pickup_date': _pickupDate.toIso8601String(), 'delivery_date': _deliveryDate.toIso8601String(),
        'manual_customer_name': _nameCtrl.text.trim(), 'manual_customer_phone': _phoneCtrl.text.trim()
      };

      Map<String, dynamic> finalOrder;

      if (isEdit) {
        final res = await supabase.from(AppConstants.ordersTable).update(payload).eq('id', widget.existingOrder!['id']).select('*, services(title), stores(name)').single();
        finalOrder = res;
      } else {
        payload['order_number'] = 'EZ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        payload['status'] = 'pending'; payload['progress'] = 0.1; payload['is_manual'] = true;
        final res = await supabase.from(AppConstants.ordersTable).insert(payload).select('*, services(title), stores(name)').single();
        finalOrder = res;
      }

      widget.onAdded();
      if (mounted) Navigator.pop(context);
      widget.onPrint(finalOrder);

    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error)); }
    setState(() => _loading = false);
  }

  InputDecoration _deco(BuildContext context, String hint) => InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: _subtextColor(context).withOpacity(0.6), fontSize: 14), filled: true, fillColor: _inputFillColor(context), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor(context))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)));
  Widget _label(BuildContext context, String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor(context))));

  @override Widget build(BuildContext context) {
    final isEdit = widget.existingOrder != null;
    final needsPickupAddr = _logisticsMode == 'full_service';
    final needsDeliveryAddr = _logisticsMode == 'full_service' || _logisticsMode == 'delivery_only';

    return Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent, // Ensures BackdropFilter works
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                    constraints: const BoxConstraints(maxWidth: 650, maxHeight: 850),
                    decoration: BoxDecoration(
                      color: _surfaceColor(context),
                      border: Border.all(color: Colors.white.withOpacity(_isDark(context) ? 0.05 : 0.5), width: 1.5),
                    ),
                    child: Padding(padding: const EdgeInsets.all(32), child: Form(key: _formKey, child: Column(children: [
                      Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isEdit ? Icons.edit_document : Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 24)), const SizedBox(width: 16), Text(isEdit ? 'Edit Order' : 'Add New Order', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _textColor(context))), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: _subtextColor(context)))]),
                      const SizedBox(height: 24), Divider(height: 1, color: _borderColor(context)), const SizedBox(height: 24),
                      Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Customer Name *'), TextFormField(controller: _nameCtrl, style: TextStyle(color: _textColor(context)), decoration: _deco(context, 'Enter name'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null)])),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Phone Number *'), TextFormField(controller: _phoneCtrl, style: TextStyle(color: _textColor(context)), keyboardType: TextInputType.phone, decoration: _deco(context, 'Enter phone'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null)])),
                        ]), const SizedBox(height: 20),

                        _label(context, 'Logistics Mode'),
                        DropdownButtonFormField<String>(
                          value: _logisticsMode,
                          dropdownColor: _surfaceColor(context),
                          items: [
                            DropdownMenuItem(value: 'full_service', child: Text('Full Service (Rider Pickup & Delivery)', style: TextStyle(color: _textColor(context)))),
                            DropdownMenuItem(value: 'delivery_only', child: Text('Drop-off & Delivery (Rider Delivers)', style: TextStyle(color: _textColor(context)))),
                            DropdownMenuItem(value: 'self_service', child: Text('Self Service (Customer Pick-up)', style: TextStyle(color: _textColor(context)))),
                          ],
                          onChanged: (v) => setState(() { _logisticsMode = v!; _sameAsPickup = false; }),
                          decoration: _deco(context, ''),
                        ),
                        const SizedBox(height: 20),

                        if (needsPickupAddr) ...[
                          _label(context, 'Pickup Address *'), TextFormField(controller: _pickupAddrCtrl, style: TextStyle(color: _textColor(context)), maxLines: 2, decoration: _deco(context, 'Enter pickup address'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null), const SizedBox(height: 20),
                        ],

                        if (needsDeliveryAddr) ...[
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _label(context, 'Delivery Address *'),
                            if (needsPickupAddr) Row(children: [Checkbox(value: _sameAsPickup, activeColor: AppColors.primary, onChanged: (v) { setState(() { _sameAsPickup = v!; if (v) _deliveryAddrCtrl.text = _pickupAddrCtrl.text; else _deliveryAddrCtrl.clear(); }); }), Text('Same as Pickup', style: GoogleFonts.inter(fontSize: 13, color: _textColor(context)))])
                          ]),
                          TextFormField(controller: _deliveryAddrCtrl, style: TextStyle(color: _textColor(context)), maxLines: 2, decoration: _deco(context, 'Enter delivery address'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null), const SizedBox(height: 20),
                        ],

                        Row(children: [
                          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Service'), DropdownButtonFormField<String>(dropdownColor: _surfaceColor(context), value: _selectedServiceId, items: _services.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['title'] as String, style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))))).toList(), onChanged: (v) { setState(() => _selectedServiceId = v); _calculatePrice(); }, decoration: _deco(context, ''))])),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Qty'), TextFormField(controller: _qtyCtrl, style: TextStyle(color: _textColor(context)), keyboardType: TextInputType.number, decoration: _deco(context, '1'), onChanged: (_) => _calculatePrice(), validator: (v) => (int.tryParse(v ?? '') == null) ? 'Invalid' : null)])),
                          const SizedBox(width: 16),
                          if (widget.isSuperAdmin) Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Store *'), DropdownButtonFormField<String>(dropdownColor: _surfaceColor(context), value: _selectedStoreId, hint: Text('Select', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))), items: _stores.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String, style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))))).toList(), onChanged: (v) => setState(() => _selectedStoreId = v), decoration: _deco(context, ''), validator: (v) => v == null ? 'Required' : null)])),
                        ]), const SizedBox(height: 20),

                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Price (৳) *'), TextFormField(controller: _priceCtrl, style: TextStyle(color: _textColor(context)), keyboardType: TextInputType.number, decoration: _deco(context, '0'), validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)])),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Pickup Date'), InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _pickupDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setState(() { _pickupDate = d; _deliveryDate = d.add(const Duration(days: 1)); }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: _inputFillColor(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor(context))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}', style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))), const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20)])))])),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(context, 'Delivery Date'), InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _deliveryDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setState(() => _deliveryDate = d); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: _inputFillColor(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor(context))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_deliveryDate.day}/${_deliveryDate.month}/${_deliveryDate.year}', style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))), const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20)])))]))
                        ]),
                      ]))),
                      const SizedBox(height: 24), Divider(height: 1, color: _borderColor(context)), const SizedBox(height: 24),
                      Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), side: BorderSide(color: _borderColor(context)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Cancel', style: GoogleFonts.inter(color: _textColor(context), fontWeight: FontWeight.w600, fontSize: 15)))), const SizedBox(width: 16), Expanded(child: _GradientButton(label: _loading ? 'Saving…' : (isEdit ? 'Update Order' : 'Save & Print Receipt'), icon: Icons.print_outlined, onPressed: _loading ? null : () => _submit()))]),
                    ]))
                    )
                )
            )
        ));
  }
}

class _GradientButton extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback? onPressed;
  const _GradientButton({required this.label, required this.icon, this.onPressed});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: onPressed != null ? AppColors.gradient : null, color: onPressed == null ? _borderColor(context) : null, borderRadius: BorderRadius.circular(12), boxShadow: onPressed != null ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : []), child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, color: Colors.white, size: 20), label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
}