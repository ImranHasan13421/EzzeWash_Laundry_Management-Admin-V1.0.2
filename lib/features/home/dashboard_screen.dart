// lib/features/home/dashboard_screen.dart
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

// --- DYNAMIC THEME HELPERS ---
bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
Color _bgColor(BuildContext context) => _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
Color _surfaceColor(BuildContext context) => _isDark(context) ? const Color(0xFF1E293B) : Colors.white;
Color _textColor(BuildContext context) => _isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
Color _subtextColor(BuildContext context) => _isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _borderColor(BuildContext context) => _isDark(context) ? const Color(0xFF475569) : const Color(0xFFE2E8F0);

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
        final res = await supabase.from('team_members').select('store_id, stores(name, city)').eq('email', email ?? '').maybeSingle();
        if (res != null) {
          _managerStoreId = res['store_id'];
          if (res['stores'] != null) {
            final sName = res['stores']['name'] ?? '';
            final sCity = res['stores']['city'] ?? '';
            _managerStoreName = sCity.isNotEmpty ? '$sName, $sCity' : sName;
          } else {
            _managerStoreName = 'Assigned Store';
          }
        }
      } catch (e) {
        debugPrint("Error fetching manager role: $e");
      }
    }
    if (mounted) setState(() => _isLoadingRole = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return Scaffold(backgroundColor: _bgColor(context), body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final pages = [
      _DashboardHome(
        isSuperAdmin: _isSuperAdmin,
        managerStoreId: _managerStoreId,
        managerStoreName: _managerStoreName,
        onNavigate: (i) => setState(() => _selectedIndex = i),
        onNavigateToStatus: (status) {
          setState(() => _selectedIndex = 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _orderKey.currentState?.setStatusFilter(status);
          });
        },
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

    return Scaffold(
      backgroundColor: _bgColor(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < 1100;
          return Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: collapsed ? 80 : 260,
              decoration: BoxDecoration(color: _surfaceColor(context), border: Border(right: BorderSide(color: _borderColor(context), width: 1.5))),
              child: _Sidebar(
                collapsed: collapsed,
                selectedIndex: _selectedIndex,
                onItemSelected: (i) => setState(() => _selectedIndex = i),
              ),
            ),
            Expanded(child: pages[_selectedIndex]),
          ]);
        },
      ),
    );
  }
}

// ─── SIDEBAR ────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({required this.collapsed, required this.selectedIndex, required this.onItemSelected});

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag, 'Orders'),
    (Icons.delivery_dining, Icons.delivery_dining, 'Riders'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 32),
      collapsed
          ? Container(
        width: 44, height: 44,
        decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
        child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 24),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Flexible(child: Text('EzeeWash', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: _textColor(context)))),
        ]),
      ),
      const SizedBox(height: 40),
      ...List.generate(_items.length, (i) {
        final active = selectedIndex == i;
        final item = _items[i];
        return GestureDetector(
          onTap: () => onItemSelected(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16, vertical: 14),
            decoration: BoxDecoration(
              color: active ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
              Icon(active ? item.$2 : item.$1, size: 22, color: active ? AppColors.primary : _subtextColor(context)),
              if (!collapsed) ...[
                const SizedBox(width: 14),
                Flexible(child: Text(item.$3, style: GoogleFonts.inter(color: active ? AppColors.primary : _subtextColor(context), fontWeight: active ? FontWeight.bold : FontWeight.w600, fontSize: 15))),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.error.withOpacity(0.1)),
          child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
            const Icon(Icons.logout, size: 22, color: AppColors.error),
            if (!collapsed) ...[
              const SizedBox(width: 14),
              Flexible(child: Text('Sign Out', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15))),
            ],
          ]),
        ),
      ),
    ]);
  }
}

// ─── DASHBOARD HOME ──────────────────────────────────────────────────────────

class _DashboardHome extends StatefulWidget {
  final bool isSuperAdmin;
  final String? managerStoreId;
  final String? managerStoreName;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onNavigateToStatus;
  final VoidCallback onAddOrder;

  const _DashboardHome({required this.isSuperAdmin, this.managerStoreId, this.managerStoreName, required this.onNavigate, required this.onNavigateToStatus, required this.onAddOrder});
  @override State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _actionRequired = [];
  List<Map<String, dynamic>> _liveRiders = [];
  List<double> _weeklyRevenue = [];
  List<String> _weeklyLabels = [];
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _ridersChannel;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _ridersChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    PostgresChangeFilter? orderFilter;
    if (!widget.isSuperAdmin && widget.managerStoreId != null) {
      orderFilter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'store_id', value: widget.managerStoreId!);
    }
    _ordersChannel = supabase.channel('dashboard_orders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AppConstants.ordersTable, filter: orderFilter, callback: (_) => _loadStats()).subscribe();
    _ridersChannel = supabase.channel('dashboard_riders').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: AppConstants.ridersTable, callback: (_) => _loadStats()).subscribe();
  }

  Future<void> _loadStats() async {
    try {
      var query = supabase.from(AppConstants.ordersTable).select('id, order_number, status, total_price, created_at, profiles(full_name), services(title)');
      if (!widget.isSuperAdmin && widget.managerStoreId != null) query = query.eq('store_id', widget.managerStoreId!);
      final ordersData = await query.order('created_at', ascending: false);
      final ridersData = await supabase.from(AppConstants.ridersTable).select('id, full_name, vehicle_type, vehicle_plate, is_online, is_active, avatar_url').eq('is_online', true);

      final all = ordersData as List;
      final pending = all.where((o) => o['status'] == 'pending').length;
      final active = all.where((o) => !['delivered', 'cancelled'].contains(o['status'])).toList();
      final delivered = all.where((o) => o['status'] == 'delivered').length;

      final today = DateTime.now();
      double todayRev = 0;
      List<double> weekRev = List.filled(7, 0.0);
      List<String> weekLbl = List.filled(7, '');
      for (int i = 6; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        weekLbl[6 - i] = '${d.day}/${d.month}';
      }

      for (var o in all) {
        if (o['created_at'] == null) continue;
        final d = DateTime.parse(o['created_at']);
        final price = (o['total_price'] as num?)?.toDouble() ?? 0.0;
        if (d.year == today.year && d.month == today.month && d.day == today.day) todayRev += price;
        final diffDays = today.difference(DateTime(d.year, d.month, d.day)).inDays;
        if (diffDays >= 0 && diffDays < 7) weekRev[6 - diffDays] += price;
      }
      active.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));

      if (mounted) {
        setState(() {
          _stats = {'total': all.length, 'pending': pending, 'active': active.length, 'delivered': delivered, 'todayRevenue': todayRev, 'ridersOnline': (ridersData as List).length};
          _weeklyRevenue = weekRev;
          _weeklyLabels = weekLbl;
          _actionRequired = List<Map<String, dynamic>>.from(active.take(6));
          _liveRiders = List<Map<String, dynamic>>.from(ridersData);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
        backgroundColor: _surfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context), width: 1.5)),
        title: Text(nextStatus == 'picked_up' ? 'Dispatch for Pickup' : 'Dispatch for Delivery', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: _textColor(context))),
        content: SizedBox(width: 440, child: availableRiders.isEmpty ? Padding(padding: const EdgeInsets.all(24), child: Text("No active riders available.", style: GoogleFonts.inter(color: _subtextColor(context)))) : ListView.separated(shrinkWrap: true, itemCount: availableRiders.length, separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)), itemBuilder: (c, i) {
          final r = availableRiders[i]; final isOnline = r['is_online'] == true; final avatar = r['avatar_url'] as String?;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null, child: (avatar == null || avatar.isEmpty) ? Text(r['full_name'][0].toUpperCase(), style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)) : null),
            title: Text(r['full_name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))),
            subtitle: Text('${r['vehicle_type']} • ${r['vehicle_plate']}', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context))),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isOnline ? AppColors.success : Colors.grey.shade400).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.inter(fontSize: 11, color: isOnline ? AppColors.success : Colors.grey.shade500, fontWeight: FontWeight.bold))),
            onTap: () { Navigator.pop(ctx); _assignRiderAndStatus(orderId, r['id'], nextStatus); },
          );
        })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context), fontWeight: FontWeight.bold)))],
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      _buildHeader(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            _StatsGrid(stats: _stats),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 1100) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: _WeeklyRevenueChart(revenue: _weeklyRevenue, labels: _weeklyLabels)),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: _QuickActions(onNavigate: widget.onNavigate, onAddOrder: widget.onAddOrder))
                ]);
              }
              return Column(children: [_WeeklyRevenueChart(revenue: _weeklyRevenue, labels: _weeklyLabels), const SizedBox(height: 24), _QuickActions(onNavigate: widget.onNavigate, onAddOrder: widget.onAddOrder)]);
            }),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > 1100) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: _ActionRequiredFeed(orders: _actionRequired, onNavigate: widget.onNavigate, onNavigateToStatus: widget.onNavigateToStatus, onAction: _handleQuickAction)),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: _LiveRidersPanel(riders: _liveRiders, onNavigate: widget.onNavigate))
                ]);
              }
              return Column(children: [_ActionRequiredFeed(orders: _actionRequired, onNavigate: widget.onNavigate, onNavigateToStatus: widget.onNavigateToStatus, onAction: _handleQuickAction), const SizedBox(height: 24), _LiveRidersPanel(riders: _liveRiders, onNavigate: widget.onNavigate)]);
            }),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildHeader() {
    return Container(
      height: 72, padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(color: _surfaceColor(context), border: Border(bottom: BorderSide(color: _borderColor(context), width: 1.5))),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [
            Text('Overview', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: _textColor(context))),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.circle, color: AppColors.success, size: 8),
                const SizedBox(width: 6),
                Text('LIVE', style: GoogleFonts.inter(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          Row(children: [
            Text(widget.isSuperAdmin ? 'Welcome Super Admin' : 'Welcome Manager', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
            if (!widget.isSuperAdmin && widget.managerStoreName != null) ...[
              Text(' • ', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
              Text(widget.managerStoreName!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold)),
            ]
          ]),
        ]),
        const Spacer(),
        IconButton(icon: Icon(Icons.refresh_rounded, color: _textColor(context)), onPressed: () { setState((){_loading=true;}); _loadStats(); }),
      ]),
    );
  }
}

// ─── SUB-COMPONENTS ──────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatData('Total Orders', '${stats['total'] ?? 0}', '+all time', AppColors.primary, Icons.receipt_long_outlined),
      _StatData('Active Orders', '${stats['active'] ?? 0}', 'in progress', AppColors.warning, Icons.pending_actions_outlined),
      _StatData('Completed', '${stats['delivered'] ?? 0}', 'delivered', AppColors.success, Icons.check_circle_outline),
      _StatData('Pending', '${stats['pending'] ?? 0}', 'awaiting', const Color(0xFF8B5CF6), Icons.access_time_outlined),
      _StatData('Today Revenue', '৳${(stats['todayRevenue'] ?? 0.0).toStringAsFixed(0)}', 'today', AppColors.success, Icons.trending_up_rounded),
      _StatData('Riders Online', '${stats['ridersOnline'] ?? 0}', 'active now', AppColors.info, Icons.delivery_dining_outlined),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      int cols = constraints.maxWidth < 600 ? 1 : constraints.maxWidth < 1100 ? 2 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            mainAxisExtent: 180
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _StatCard(data: cards[i]),
      );
    });
  }
}

class _StatData {
  final String title, value, subtitle;
  final Color color;
  final IconData icon;
  const _StatData(this.title, this.value, this.subtitle, this.color, this.icon);
}

class _StatCard extends StatefulWidget {
  final _StatData data;
  const _StatCard({required this.data});
  @override State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final numVal = double.tryParse(widget.data.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final prefix = widget.data.value.contains('৳') ? '৳' : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: _hover ? widget.data.color : _borderColor(context),
              width: _hover ? 2.0 : 1.5
          ),
          boxShadow: [
            if (_hover)
              BoxShadow(
                  color: widget.data.color.withOpacity(_isDark(context) ? 0.5 : 0.35),
                  blurRadius: 30,
                  spreadRadius: 4,
                  offset: const Offset(0, 8)
              )
            else
              BoxShadow(
                  color: Colors.black.withOpacity(_isDark(context) ? 0.4 : 0.04),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 6)
              )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.data.color.withOpacity(0.15), borderRadius: BorderRadius.circular(16)), child: Icon(widget.data.icon, color: widget.data.color, size: 24)),
            Text(widget.data.subtitle, style: GoogleFonts.inter(color: widget.data.color, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.data.title, style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 14, fontWeight: FontWeight.w600)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: numVal),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) => Text('$prefix${value.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: _textColor(context))),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _WeeklyRevenueChart extends StatelessWidget {
  final List<double> revenue; final List<String> labels;
  const _WeeklyRevenueChart({required this.revenue, required this.labels});
  @override Widget build(BuildContext context) {
    final maxRev = revenue.isEmpty ? 1.0 : revenue.reduce(max);
    return Container(
      height: 255, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor(context), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 4))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('7-Day Revenue Trend', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor(context))), const SizedBox(height: 24),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final availableHeight = constraints.maxHeight - 55;
          final maxBarHeight = availableHeight > 0 ? availableHeight * 0.85 : 0.0;
          return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
            final hPct = maxRev == 0 ? 0.0 : (revenue[i] / maxRev);
            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 600 + (i * 100)),
                builder: (context, val, child) => Opacity(opacity: val, child: Text('৳${revenue[i].toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 10, color: _subtextColor(context), fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: hPct),
                duration: Duration(milliseconds: 1000 + (i * 150)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Container(
                    width: 24,
                    height: maxBarHeight > 0 ? max(0.0, maxBarHeight * value) : 0.0,
                    decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                  );
                },
              ),
              const SizedBox(height: 10), Text(labels[i], style: GoogleFonts.inter(fontSize: 10, color: _subtextColor(context), fontWeight: FontWeight.w600)),
            ]);
          }));
        })),
      ]),
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
        height: 255, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 4))]
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick Actions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor(context))), const SizedBox(height: 12),
          Expanded(child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 75), itemCount: actions.length, itemBuilder: (_, i) => _ActionTile(icon: actions[i].$1, title: actions[i].$2, sub: actions[i].$3, onTap: actions[i].$4))),
        ])
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon; final String title, sub; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: _hover ? AppColors.primary.withOpacity(0.05) : _bgColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hover ? AppColors.primary : _borderColor(context),
                width: _hover ? 2.0 : 1.5,
              ),
              boxShadow: [
                if (_hover)
                  BoxShadow(color: AppColors.primary.withOpacity(_isDark(context) ? 0.3 : 0.2), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4))
              ]
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _hover ? AppColors.primary : AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, color: _hover ? Colors.white : AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                const SizedBox(height: 2),
                Text(widget.sub, style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context), fontWeight: FontWeight.w500)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

class _ActionRequiredFeed extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onNavigateToStatus;
  final void Function(String, String) onAction;

  const _ActionRequiredFeed({required this.orders, required this.onNavigate, required this.onNavigateToStatus, required this.onAction});

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
      decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor(context), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 4))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // --- THE TINTED HEADER ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _isDark(context) ? Colors.redAccent.withOpacity(0.08) : Colors.red.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _FlickerText(
                text: 'Attention Required',
                style: GoogleFonts.outfit(fontSize: 18, color: _isDark(context) ? Colors.redAccent : Colors.red, fontWeight: FontWeight.bold)
            ),
            GestureDetector(onTap: () => onNavigate(1), child: Text('Manage Orders', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)))
          ]),
        ),
        Divider(height: 1, color: _borderColor(context)),
        // -------------------------

        if (orders.isEmpty) Padding(padding: const EdgeInsets.all(48), child: Center(child: Text('All caught up! Great job.', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 15))))
        else ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: orders.length, separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)), itemBuilder: (context, i) {

          final o = orders[i];
          final urgency = _getUrgencyInfo(o['created_at'], o['status']);
          final uColor = urgency['color'] as Color;
          final isActionable = ['pending', 'confirmed', 'ready'].contains(o['status']);
          final displayName = o['is_manual'] == true ? (o['manual_customer_name'] ?? 'Manual Customer') : ((o['profiles'] as Map?)?['full_name'] ?? 'Guest');

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onNavigateToStatus(o['status']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(color: (urgency['isUrgent'] as bool) ? uColor.withOpacity(_isDark(context) ? 0.05 : 0.02) : Colors.transparent),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: uColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.warning_amber_rounded, color: uColor, size: 22)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${o['order_number']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor(context))),
                    const SizedBox(height: 4),
                    Text('$displayName • ${o['status'].toString().toUpperCase().replaceAll('_', ' ')}', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context), fontWeight: FontWeight.w600)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(urgency['text'], style: GoogleFonts.inter(color: uColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (isActionable) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => onAction(o['id'], o['status']),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: const Size(0, 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 3,
                            shadowColor: AppColors.primary.withOpacity(0.5)
                        ),
                        child: Text(o['status'] == 'pending' ? 'Accept Order' : 'Dispatch', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ]),
                  const SizedBox(width: 16),
                  Icon(Icons.chevron_right_rounded, color: _subtextColor(context)),
                ]),
              ),
            ),
          );
        }
        )
      ]),
    );
  }
}

class _LiveRidersPanel extends StatelessWidget {
  final List<Map<String, dynamic>> riders; final ValueChanged<int> onNavigate;
  const _LiveRidersPanel({required this.riders, required this.onNavigate});
  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor(context), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 4))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // --- THE TINTED HEADER ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _isDark(context) ? Colors.greenAccent.withOpacity(0.08) : Colors.green.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _FlickerText(
                text: 'Live Dispatch',
                style: GoogleFonts.outfit(fontSize: 18, color: _isDark(context) ? Colors.greenAccent : Colors.green, fontWeight: FontWeight.bold)
            ),
            GestureDetector(onTap: () => onNavigate(2), child: Text('View All', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)))
          ]),
        ),
        Divider(height: 1, color: _borderColor(context)),
        // -------------------------

        if (riders.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No online riders.', style: GoogleFonts.inter(color: _subtextColor(context)))))
        else ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: riders.length, separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)), itemBuilder: (context, i) {
          final r = riders[i];
          return ListTile(
            onTap: () => onNavigate(2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.15), backgroundImage: (r['avatar_url'] != null && r['avatar_url'].isNotEmpty) ? NetworkImage(r['avatar_url']) : null, child: (r['avatar_url'] == null || r['avatar_url'].isEmpty) ? Text(r['full_name'][0], style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)) : null),
            title: Text(r['full_name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textColor(context))),
            subtitle: Text(r['vehicle_plate'] ?? 'No Plate', style: GoogleFonts.inter(fontSize: 12, color: _subtextColor(context), fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('READY', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: _subtextColor(context)),
              ],
            ),
          );
        })
      ]),
    );
  }
}

// ─── FLICKER ANIMATION WIDGET ───────────────────────────────────────────

class _FlickerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _FlickerText({required this.text, required this.style});

  @override
  State<_FlickerText> createState() => _FlickerTextState();
}

class _FlickerTextState extends State<_FlickerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Text(widget.text, style: widget.style),
    );
  }
}