// lib/features/home/dashboard_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../core/theme/color/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../main.dart';
import '../auth/admin_login_screen.dart';
import 'order_screen.dart';
import 'riders_screen.dart';
import 'report_screen.dart';
import 'admin_settings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<OrderScreenState> _orderKey = GlobalKey<OrderScreenState>();

  bool _isLoadingRole = true;
  bool _isSuperAdmin = false;
  String? _managerStoreId;
  String? _managerStoreName;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initRoleAndPages();
  }

  Future<void> _initRoleAndPages() async {
    final email = supabase.auth.currentUser?.email;

    if (email == 'abdulaowalasif2001@gmail.com') {
      _isSuperAdmin = true;
    } else {
      try {
        // Fetch store_id, name, AND city!
        final res = await supabase.from('team_members').select('store_id, stores(name, city)').eq('email', email ?? '').maybeSingle();
        if (res != null) {
          _managerStoreId = res['store_id'];
          if (res['stores'] != null) {
            final sName = res['stores']['name'] ?? '';
            final sCity = res['stores']['city'] ?? '';
            // Combines them: "EzeeWash Gulshan, Dhaka"
            _managerStoreName = sCity.isNotEmpty ? '$sName, $sCity' : sName;
          } else {
            _managerStoreName = 'Assigned Store';
          }
        }
      } catch (e) {
        debugPrint("Error fetching manager role: $e");
      }
    }

    if (mounted) {
      setState(() {
        _pages = [
          _DashboardHome(
            isSuperAdmin: _isSuperAdmin,
            managerStoreId: _managerStoreId,
            managerStoreName: _managerStoreName,
            onNavigate: (i) => setState(() => _selectedIndex = i),
            onAddOrder: () {
              setState(() => _selectedIndex = 1);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _orderKey.currentState?.openAddOrderDialog();
              });
            },
          ),
          OrderScreen(key: _orderKey, isSuperAdmin: _isSuperAdmin, managerStoreId: _managerStoreId),
          RidersScreen(isSuperAdmin: _isSuperAdmin),
          ReportsScreen(isSuperAdmin: _isSuperAdmin, managerStoreId: _managerStoreId),
          SettingsScreen(isSuperAdmin: _isSuperAdmin, managerStoreId: _managerStoreId),
        ];
        _isLoadingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return  Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < 1100;
          return Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: collapsed ? 80 : 260,
              decoration:  BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.border))),
              child: _Sidebar(
                collapsed: collapsed,
                selectedIndex: _selectedIndex,
                onItemSelected: (i) => setState(() => _selectedIndex = i),
              ),
            ),
            Expanded(child: _pages[_selectedIndex]),
          ]);
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({required this.collapsed, required this.selectedIndex, required this.onItemSelected});

  static const _items = [
    (Icons.dashboard_outlined,    Icons.dashboard,       'Dashboard'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag,    'Orders'),
    (Icons.delivery_dining,       Icons.delivery_dining, 'Riders'),
    (Icons.bar_chart_outlined,    Icons.bar_chart,       'Reports'),
    (Icons.settings_outlined,     Icons.settings,        'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 32),
      collapsed
          ? Container(
        width: 44, height: 44,
        decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
        child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 24),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
            child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Flexible(child: Text('EzeeWash', overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text))),
        ]),
      ),
      const SizedBox(height: 40),
      ...List.generate(_items.length, (i) {
        final active = selectedIndex == i;
        final item   = _items[i];
        return GestureDetector(
          onTap: () => onItemSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16, vertical: 14),
            decoration: BoxDecoration(
              color: active ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
              Icon(active ? item.$2 : item.$1, size: 22, color: active ? AppColors.primary : AppColors.subtext),
              if (!collapsed) ...[
                const SizedBox(width: 14),
                Flexible(child: Text(item.$3, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: active ? AppColors.primary : AppColors.subtext, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 15))),
              ],
            ]),
          ),
        );
      }),
      const Spacer(),
      GestureDetector(
        onTap: () async {
          await supabase.auth.signOut();
          if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()), (_) => false);
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.error.withOpacity(0.05)),
          child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
            const Icon(Icons.logout, size: 22, color: AppColors.error),
            if (!collapsed) ...[
              const SizedBox(width: 14),
              Flexible(child: Text('Sign Out', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 15))),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _DashboardHome extends StatefulWidget {
  final bool isSuperAdmin;
  final String? managerStoreId;
  final String? managerStoreName;
  final ValueChanged<int> onNavigate;
  final VoidCallback onAddOrder;

  const _DashboardHome({required this.isSuperAdmin, this.managerStoreId, this.managerStoreName, required this.onNavigate, required this.onAddOrder});
  @override State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  bool _loading = true; String? _error;
  Map<String, dynamic> _stats = {}; List<Map<String, dynamic>> _actionRequired = []; List<Map<String, dynamic>> _liveRiders = []; List<double> _weeklyRevenue = []; List<String> _weeklyLabels = [];
  RealtimeChannel? _ordersChannel; RealtimeChannel? _ridersChannel;

  @override void initState() { super.initState(); _loadStats(); _subscribeRealtime(); }
  @override void dispose() { _ordersChannel?.unsubscribe(); _ridersChannel?.unsubscribe(); super.dispose(); }

  void _subscribeRealtime() {
    PostgresChangeFilter? orderFilter;

    if (!widget.isSuperAdmin && widget.managerStoreId != null) {
      orderFilter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'store_id',
        value: widget.managerStoreId!,
      );
    }

    _ordersChannel = supabase.channel('dashboard_orders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AppConstants.ordersTable, filter: orderFilter, callback: (_) => _loadStats()).subscribe();
    _ridersChannel = supabase.channel('dashboard_riders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AppConstants.ridersTable, callback: (_) => _loadStats()).subscribe();
  }

  Future<void> _loadStats() async {
    try {
      var query = supabase.from(AppConstants.ordersTable).select('id, order_number, status, total_price, created_at, profiles(full_name), services(title)');

      // MANAGER FILTER
      if (!widget.isSuperAdmin && widget.managerStoreId != null) {
        query = query.eq('store_id', widget.managerStoreId!);
      }

      final ordersData = await query.order('created_at', ascending: false);
      final ridersData = await supabase.from(AppConstants.ridersTable).select('id, full_name, vehicle_type, vehicle_plate, is_online, is_active, avatar_url').eq('is_online', true);

      final all = ordersData as List;
      final pending   = all.where((o) => o['status'] == 'pending').length;
      final active    = all.where((o) => !['delivered', 'cancelled'].contains(o['status'])).toList();
      final delivered = all.where((o) => o['status'] == 'delivered').length;

      final today = DateTime.now(); double todayRev = 0;
      List<double> weekRev = List.filled(7, 0.0); List<String> weekLbl = List.filled(7, '');
      for(int i=6; i>=0; i--) { final d = today.subtract(Duration(days: i)); weekLbl[6-i] = '${d.day}/${d.month}'; }

      for (var o in all) {
        if (o['created_at'] == null) continue;
        final d = DateTime.parse(o['created_at']);
        final price = (o['total_price'] as num?)?.toDouble() ?? 0.0;
        if (d.year == today.year && d.month == today.month && d.day == today.day) todayRev += price;
        final diffDays = today.difference(DateTime(d.year, d.month, d.day)).inDays;
        if (diffDays >= 0 && diffDays < 7) weekRev[6 - diffDays] += price;
      }
      active.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
      final topActionRequired = active.take(6).toList();

      if (mounted) setState(() {
        _stats = {'total': all.length, 'pending': pending, 'active': active.length, 'delivered': delivered, 'todayRevenue': todayRev, 'ridersOnline': (ridersData as List).length};
        _weeklyRevenue = weekRev; _weeklyLabels = weekLbl; _actionRequired = List<Map<String, dynamic>>.from(topActionRequired); _liveRiders = List<Map<String, dynamic>>.from(ridersData); _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _assignRiderAndStatus(String orderId, String riderId, String nextStatus) async {
    double progress = nextStatus == 'picked_up' ? 0.4 : (nextStatus == 'out_for_delivery' ? 0.9 : 0.0);
    try {
      await supabase.rpc('rider_update_order_status', params: {'p_order_id': orderId, 'p_rider_id': riderId, 'p_status': nextStatus, 'p_progress': progress});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rider dispatched successfully!', style: GoogleFonts.inter()), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dispatch Error: $e', style: GoogleFonts.inter()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _showRiderSelection(String orderId, String nextStatus) async {
    final res = await supabase.from(AppConstants.ridersTable).select().eq('is_active', true);
    final availableRiders = List<Map<String, dynamic>>.from(res);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(nextStatus == 'picked_up' ? 'Dispatch for Pickup' : 'Dispatch for Delivery', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
        content: SizedBox(width: 440, child: availableRiders.isEmpty ? Padding(padding: const EdgeInsets.all(24), child: Text("No active riders available.", style: GoogleFonts.inter())) : ListView.separated(shrinkWrap: true, itemCount: availableRiders.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final r = availableRiders[i]; final isOnline = r['is_online'] == true; final avatar = r['avatar_url'] as String?;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null, child: (avatar == null || avatar.isEmpty) ? Text(r['full_name'][0].toUpperCase(), style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)) : null),
            title: Text(r['full_name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('${r['vehicle_type']} • ${r['vehicle_plate']}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext)),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isOnline ? AppColors.success : Colors.grey.shade400).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.inter(fontSize: 11, color: isOnline ? AppColors.success : Colors.grey.shade600, fontWeight: FontWeight.bold))),
            onTap: () { Navigator.pop(ctx); _assignRiderAndStatus(orderId, r['id'], nextStatus); },
          );
        })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.subtext, fontWeight: FontWeight.w600)))],
      ),
    );
  }

  Future<void> _handleQuickAction(String orderId, String currentStatus) async {
    if (currentStatus == 'pending') {
      await supabase.from(AppConstants.ordersTable).update({'status': 'confirmed', 'progress': 0.2}).eq('id', orderId);
      if (mounted) _showRiderSelection(orderId, 'picked_up');
    } else if (currentStatus == 'confirmed') {
      _showRiderSelection(orderId, 'picked_up');
    } else if (currentStatus == 'ready') {
      _showRiderSelection(orderId, 'out_for_delivery');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, color: AppColors.error, size: 48), const SizedBox(height: 12), Text(_error!, style: GoogleFonts.inter(color: AppColors.error)), const SizedBox(height: 16), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: Text('Retry', style: GoogleFonts.inter()), onPressed: () => setState(() { _error = null; _loading = true; _loadStats(); }))]));

    return Column(children: [
      Container(
        height: 72, padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration:  BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Text('Overview', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)), const SizedBox(width: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.circle, color: AppColors.success, size: 8), const SizedBox(width: 6), Text('Live Updates', style: GoogleFonts.inter(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold))]))
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text(widget.isSuperAdmin ? 'Welcome Super Admin' : 'Welcome Manager', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext)),
              if (!widget.isSuperAdmin && widget.managerStoreName != null) ...[
                Text(' • ', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext)),
                Text(widget.managerStoreName!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]
            ]),
          ]),
          const Spacer(),
          Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: IconButton(icon: Icon(Icons.refresh_rounded, color: AppColors.text), onPressed: () { setState((){_loading=true;}); _loadStats(); })),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _StatsGrid(stats: _stats), const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _WeeklyRevenueChart(revenue: _weeklyRevenue, labels: _weeklyLabels)), const SizedBox(width: 24), Expanded(flex: 4, child: _QuickActions(onNavigate: widget.onNavigate, onAddOrder: widget.onAddOrder))]);
              return Column(children: [_WeeklyRevenueChart(revenue: _weeklyRevenue, labels: _weeklyLabels), const SizedBox(height: 24), _QuickActions(onNavigate: widget.onNavigate, onAddOrder: widget.onAddOrder)]);
            }),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: _ActionRequiredFeed(orders: _actionRequired, onNavigate: widget.onNavigate, onAction: _handleQuickAction)), const SizedBox(width: 24), Expanded(flex: 1, child: _LiveRidersPanel(riders: _liveRiders, onNavigate: widget.onNavigate))]);
              return Column(children: [_ActionRequiredFeed(orders: _actionRequired, onNavigate: widget.onNavigate, onAction: _handleQuickAction), const SizedBox(height: 24), _LiveRidersPanel(riders: _liveRiders, onNavigate: widget.onNavigate)]);
            }),
          ]),
        ),
      ),
    ]);
  }
}

class _WeeklyRevenueChart extends StatelessWidget {
  final List<double> revenue; final List<String> labels;
  const _WeeklyRevenueChart({required this.revenue, required this.labels});

  @override Widget build(BuildContext context) {
    final maxRev = revenue.reduce(max);
    return Container(
      height: 240, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('7-Day Revenue Trend', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)), const SizedBox(height: 24),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final maxBarHeight = constraints.maxHeight - 70;
          return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
            final hPct = maxRev == 0 ? 0.0 : (revenue[i] / maxRev);
            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('৳${revenue[i].toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.subtext, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
              AnimatedContainer(duration: const Duration(milliseconds: 500), width: 28, height: maxBarHeight > 0 ? (maxBarHeight * hPct) : 0, decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 10), Text(labels[i], style: GoogleFonts.inter(fontSize: 11, color: AppColors.subtext, fontWeight: FontWeight.w500)),
            ]);
          }));
        })),
      ]),
    );
  }
}

class _LiveRidersPanel extends StatelessWidget {
  final List<Map<String, dynamic>> riders; final ValueChanged<int> onNavigate;
  const _LiveRidersPanel({required this.riders, required this.onNavigate});

  String _vehicleEmoji(String t) { switch (t) { case 'motorcycle': return '🏍️'; case 'bicycle': return '🚲'; case 'van': return '🚐'; default: return '🚗'; } }

  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Live Dispatch', style: GoogleFonts.outfit(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => onNavigate(2), child: Text('View All', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)))])),
        const Divider(height: 1),
        if (riders.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No riders online right now.', style: GoogleFonts.inter(color: AppColors.subtext))))
        else ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: riders.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) {
          final r = riders[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: Stack(children: [CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), backgroundImage: (r['avatar_url'] != null && r['avatar_url'].isNotEmpty) ? NetworkImage(r['avatar_url']) : null, child: (r['avatar_url'] == null || r['avatar_url'].isEmpty) ? Text(r['full_name'][0], style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)) : null), Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))))]),
            title: Text(r['full_name'], style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
            subtitle: Text('${_vehicleEmoji(r['vehicle_type'] ?? '')} ${r['vehicle_plate'] ?? ''}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext)),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('Standing By', style: GoogleFonts.inter(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold))),
          );
        })
      ]),
    );
  }
}

class _ActionRequiredFeed extends StatelessWidget {
  final List<Map<String, dynamic>> orders; final ValueChanged<int> onNavigate; final void Function(String, String) onAction;
  const _ActionRequiredFeed({required this.orders, required this.onNavigate, required this.onAction});

  Map<String, dynamic> _getUrgencyInfo(String? createdAtString, String status) {
    if (createdAtString == null) return {'color': AppColors.subtext, 'text': '---', 'isUrgent': false};
    final diff = DateTime.now().difference(DateTime.parse(createdAtString));
    final hours = diff.inHours; final mins = diff.inMinutes % 60;
    String t = hours > 24 ? '${(hours / 24).floor()}d ${hours % 24}h' : '${hours}h ${mins}m';
    if (hours >= 48) return {'color': AppColors.error, 'text': '⚠️ $t Overdue', 'isUrgent': true};
    if (hours >= 24) return {'color': AppColors.warning, 'text': '⏱️ $t Urgent', 'isUrgent': true};
    if (status == 'pending') return {'color': AppColors.warning, 'text': 'Action Needed', 'isUrgent': true};
    return {'color': AppColors.subtext, 'text': 'Waiting: $t', 'isUrgent': false};
  }

  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Attention Required', style: GoogleFonts.outfit(fontSize: 18,color: Colors.red, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => onNavigate(1), child: Text('Manage Orders', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)))])),
        const Divider(height: 1),
        if (orders.isEmpty) Padding(padding: const EdgeInsets.all(48), child: Center(child: Text('All caught up! Great job.', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 15))))
        else ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = orders[i];
              final urgency = _getUrgencyInfo(o['created_at'], o['status']);
              final uColor = urgency['color'] as Color;
              final isActionable = ['pending', 'confirmed', 'ready'].contains(o['status']);
              final isManual = o['is_manual'] == true;
              final manualName = o['manual_customer_name'] as String?;
              final profileName = (o['profiles'] as Map?)?['full_name'] as String?;
              final String displayName = isManual ? (manualName ?? 'Manual Customer') : (profileName ?? 'Guest');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(color: (urgency['isUrgent'] as bool) ? uColor.withOpacity(0.02) : Colors.transparent),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: uColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.warning_amber_rounded, color: uColor, size: 22)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${o['order_number']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent,)),
                    const SizedBox(height: 4),

                    // --- FIXED: Replaced o['profiles']['full_name'] with displayName ---
                    Text('$displayName • ${o['status'].toString().toUpperCase().replaceAll('_', ' ')}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.text)),

                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(urgency['text'], style: GoogleFonts.inter(color: uColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (isActionable) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                          onTap: () => onAction(o['id'], o['status']),
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                              child: Text(o['status'] == 'pending' ? 'Accept Order' : 'Dispatch', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                          )
                      )
                    ]
                  ]),
                ]),
              );
            }
        )
      ]),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats; const _StatsGrid({required this.stats});
  @override Widget build(BuildContext context) {
    final cards = [
      _StatData('Total Orders', '${stats['total'] ?? 0}', '+all time', AppColors.primary, Icons.receipt_long_outlined),
      _StatData('Active Orders', '${stats['active'] ?? 0}', 'in progress', AppColors.warning, Icons.pending_actions_outlined),
      _StatData('Completed', '${stats['delivered'] ?? 0}', 'delivered', AppColors.success, Icons.check_circle_outline),
      _StatData('Pending', '${stats['pending'] ?? 0}', 'awaiting', const Color(0xFF8B5CF6), Icons.access_time_outlined),
      _StatData('Today Revenue', '৳${(stats['todayRevenue'] ?? 0.0).toStringAsFixed(0)}', 'today', AppColors.success, Icons.trending_up_rounded),
      _StatData('Riders Online', '${stats['ridersOnline'] ?? 0}', 'active now', AppColors.info, Icons.delivery_dining_outlined),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      int cols = constraints.maxWidth < 600 ? 1 : constraints.maxWidth < 900 ? 2 : 3;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 24, mainAxisSpacing: 24, mainAxisExtent: 160), itemCount: cards.length, itemBuilder: (_, i) => _StatCard(data: cards[i]));
    });
  }
}

class _StatData { final String title, value, subtitle; final Color color; final IconData icon; const _StatData(this.title, this.value, this.subtitle, this.color, this.icon); }
class _StatCard extends StatefulWidget { final _StatData data; const _StatCard({required this.data}); @override State<_StatCard> createState() => _StatCardState(); }
class _StatCardState extends State<_StatCard> {
  double _elev = 0;
  @override Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _elev = 8), onExit: (_) => setState(() => _elev = 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02 + (_elev * 0.005)), blurRadius: 10 + _elev, offset: Offset(0, 4 + (_elev / 2)))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.data.title, style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 8), Text(widget.data.value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text))])),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.data.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(widget.data.icon, color: widget.data.color, size: 24)),
          ]),
          Text(widget.data.subtitle, style: GoogleFonts.inter(color: widget.data.color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<int> onNavigate; final VoidCallback onAddOrder;
  const _QuickActions({required this.onNavigate, required this.onAddOrder});
  @override Widget build(BuildContext context) {
    final actions = [
      (Icons.list_alt_outlined, 'View All Orders', 'Manage all orders', () => onNavigate(1)),
      (Icons.add_circle_outline, 'Add Order', 'Create manually', onAddOrder),
      (Icons.delivery_dining_outlined, 'Manage Riders', 'View rider activity', () => onNavigate(2)),
      (Icons.bar_chart_outlined, 'Reports', 'Analytics & insights', () => onNavigate(3)),
    ];
    return Container(
        height: 240, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick Actions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)), const SizedBox(height: 5),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            int cols = constraints.maxWidth < 500 ? 1 : 2;
            return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 85), itemCount: actions.length, itemBuilder: (_, i) => _ActionTile(icon: actions[i].$1, title: actions[i].$2, sub: actions[i].$3, onTap: actions[i].$4));
          })),
        ])
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon; final String title, sub; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.sub, required this.onTap});
  @override State<_ActionTile> createState() => _ActionTileState();
}
class _ActionTileState extends State<_ActionTile> {
  bool _hover = false;
  @override Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _hover = true), onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(color: _hover ? AppColors.background : AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _hover ? AppColors.primary.withOpacity(0.3) : AppColors.border)),
        child: InkWell(
          onTap: widget.onTap, borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(widget.icon, color: AppColors.primary, size: 20)), const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text)), const SizedBox(height: 2), Text(widget.sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.subtext))])),
            ]),
          ),
        ),
      ),
    );
  }
}
