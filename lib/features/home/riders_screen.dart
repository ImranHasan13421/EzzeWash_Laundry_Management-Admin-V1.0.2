// lib/features/home/riders_screen.dart
import '../../core/constants/api_keys.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';

class RidersScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const RidersScreen({super.key, required this.isSuperAdmin});

  @override State<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends State<RidersScreen> {
  bool _loading = true; String? _error;
  List<Map<String, dynamic>> _riders = [];
  String _searchQuery = '';

  RealtimeChannel? _riderSyncChannel;
  Map<String, double> _todayCashMap = {};

  @override void initState() {
    super.initState();
    _loadRidersData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _riderSyncChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _riderSyncChannel = supabase.channel('admin_rider_updates')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: AppConstants.ridersTable,
      callback: (payload) { _loadRidersData(); },
    ).subscribe();
  }

  Future<void> _loadRidersData() async {
    if (_riders.isEmpty) setState(() => _loading = true);

    try {
      final data = await supabase.from(AppConstants.ridersTable).select().order('created_at', ascending: false);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      final ordersData = await supabase.from(AppConstants.ordersTable)
          .select('delivery_rider_id, rider_id, total_price')
          .eq('status', 'delivered')
          .gte('updated_at', todayStart);

      Map<String, double> cashMap = {};
      for(var o in ordersData) {
        String rId = o['delivery_rider_id']?.toString() ?? o['rider_id']?.toString() ?? '';
        if (rId.isNotEmpty) {
          cashMap[rId] = (cashMap[rId] ?? 0.0) + ((o['total_price'] as num?)?.toDouble() ?? 0.0);
        }
      }

      if (mounted) setState(() {
        _riders = List<Map<String, dynamic>>.from(data);
        _todayCashMap = cashMap;
        _loading = false;
      });
    }
    catch (e) { if (mounted) setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<void> _toggleActive(String riderId, bool current) async {
    final newActiveStatus = !current;
    final updateData = <String, dynamic>{'is_active': newActiveStatus};
    if (newActiveStatus == false) { updateData['is_online'] = false; }

    await supabase.from(AppConstants.ridersTable).update(updateData).eq('id', riderId);
    _loadRidersData();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchQuery.toLowerCase(); if (q.isEmpty) return _riders;
    return _riders.where((r) => (r['full_name'] ?? '').toString().toLowerCase().contains(q) || (r['phone'] ?? '').toString().toLowerCase().contains(q) || (r['vehicle_plate'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  void _showRiderForm([Map<String, dynamic>? rider]) => showDialog(context: context, builder: (_) => _RiderFormDialog(onSaved: _loadRidersData, rider: rider));

  void _showCollectCashDialog(String riderId, String riderName, double todayCash, double totalCash) {
    showDialog(context: context, builder: (_) => _CollectCashDialog(riderId: riderId, riderName: riderName, todayCash: todayCash, totalCash: totalCash, onSuccess: _loadRidersData));
  }

  void _showOrderHistoryDialog(String riderId, String riderName) {
    showDialog(context: context, builder: (_) => _RiderOrderHistoryDialog(riderId: riderId, riderName: riderName));
  }

  void _showCashHistoryDialog(String riderId, String riderName) {
    showDialog(context: context, builder: (_) => _RiderCashHistoryDialog(riderId: riderId, riderName: riderName));
  }

  // --- NEW: Calculate Payout Dialog ---
  void _showCalculatePayoutDialog(String riderId, String riderName) {
    showDialog(context: context, builder: (_) => _RiderPayoutDialog(riderId: riderId, riderName: riderName));
  }

  @override Widget build(BuildContext context) {
    final online = _riders.where((r) => r['is_online'] == true).length; final active = _riders.where((r) => r['is_active'] == true).length;

    return Column(children: [
      Container(
        height: 72, padding: const EdgeInsets.symmetric(horizontal: 32), decoration: BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Riders & Fleet', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)), Text('Manage logistics and track delivery agents', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext))]),
          const Spacer(),
          if (widget.isSuperAdmin) ...[
            _GradientButton(label: 'Add Rider', icon: Icons.add, onPressed: () => _showRiderForm()),
            const SizedBox(width: 16),
          ],
          Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border.withOpacity(0.5))), child: IconButton(icon: Icon(Icons.refresh_rounded, color: AppColors.text, size: 20), onPressed: _loadRidersData)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _RiderStat('Total Riders', _riders.length.toString(), AppColors.primary, Icons.people_outline_rounded), const SizedBox(width: 16),
              _RiderStat('Online Now', online.toString(), AppColors.success, Icons.wifi_rounded), const SizedBox(width: 16),
              _RiderStat('Active Accounts', active.toString(), AppColors.info, Icons.check_circle_outline_rounded), const SizedBox(width: 16),
              _RiderStat('Offline', (active - online).toString(), AppColors.subtext, Icons.wifi_off_rounded),
            ]),
            const SizedBox(height: 24),
            TextField(onChanged: (v) => setState(() => _searchQuery = v), style: GoogleFonts.inter(fontSize: 14), decoration: InputDecoration(hintText: 'Search by name, phone, or vehicle plate...', hintStyle: GoogleFonts.inter(color: AppColors.subtext, fontSize: 14), prefixIcon: Icon(Icons.search_rounded, color: AppColors.subtext, size: 20), filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)))),
            const SizedBox(height: 24),
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.two_wheeler_rounded, size: 64, color: AppColors.border), const SizedBox(height: 16), Text('No riders found', style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 15, fontWeight: FontWeight.w500))]))
                : ListView.separated(physics: const BouncingScrollPhysics(), itemCount: _filtered.length, separatorBuilder: (_, __) => const SizedBox(height: 16), itemBuilder: (_, i) {
              final r = _filtered[i];
              final rId = r['id'] as String;
              final rName = r['full_name'] ?? 'Rider';
              return _RiderCard(
                rider: r,
                isSuperAdmin: widget.isSuperAdmin,
                todayCash: _todayCashMap[rId] ?? 0.0,
                onToggleActive: _toggleActive,
                onEdit: () => _showRiderForm(r),
                onCollectCash: () => _showCollectCashDialog(rId, rName, _todayCashMap[rId] ?? 0.0, (r['cash_in_hand'] as num?)?.toDouble() ?? 0.0),
                onOrderHistory: () => _showOrderHistoryDialog(rId, rName),
                onCashHistory: () => _showCashHistoryDialog(rId, rName),
                onCalculatePayout: () => _showCalculatePayoutDialog(rId, rName), // NEW
              );
            })),
          ]),
        ),
      ),
    ]);
  }
}

class _RiderStat extends StatelessWidget {
  final String label, value; final Color color; final IconData icon; const _RiderStat(this.label, this.value, this.color, this.icon);
  @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 12, offset: const Offset(0, 4))]), child: Row(children: [Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text, height: 1)), const SizedBox(height: 4), Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext, fontWeight: FontWeight.w500))])])));
}

class _RiderCard extends StatelessWidget {
  final Map<String, dynamic> rider; final bool isSuperAdmin; final double todayCash;
  final Future<void> Function(String, bool) onToggleActive;
  final VoidCallback onEdit; final VoidCallback onCollectCash;
  final VoidCallback onOrderHistory; final VoidCallback onCashHistory;
  final VoidCallback onCalculatePayout;

  const _RiderCard({required this.rider, required this.isSuperAdmin, required this.todayCash, required this.onToggleActive, required this.onEdit, required this.onCollectCash, required this.onOrderHistory, required this.onCashHistory, required this.onCalculatePayout});

  String _vehicleEmoji(String t) { switch (t) { case 'motorcycle': return '🏍️'; case 'bicycle': return '🚲'; case 'van': return '🚐'; default: return '🚗'; } }

  @override Widget build(BuildContext context) {
    final isOnline = rider['is_online'] == true; final isActive = rider['is_active'] == true; final name = rider['full_name'] as String? ?? 'Rider'; final vehicle = rider['vehicle_type'] as String? ?? 'motorcycle'; final plate = rider['vehicle_plate'] as String? ?? 'No plate'; final phone = rider['phone'] as String? ?? '—'; final rating = (rider['rating'] as num?)?.toDouble() ?? 5.0; final trips = rider['total_trips'] as int? ?? 0; final avatar = rider['avatar_url'] as String?;
    final totalCash = (rider['cash_in_hand'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [CircleAvatar(radius: 30, backgroundColor: AppColors.background, backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null, child: (avatar == null || avatar.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'R', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)) : null), Positioned(bottom: 2, right: 2, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: isOnline ? AppColors.success : Colors.grey.shade400, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2.5))))]),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.text)), const SizedBox(width: 12),
                if (isSuperAdmin) InkWell(onTap: onEdit, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 14)))
              ]),
              const SizedBox(height: 6), Text('$phone  •  $plate', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext, fontWeight: FontWeight.w500)), const SizedBox(height: 12),
              Row(children: [_chip('${_vehicleEmoji(vehicle)} ${vehicle.toUpperCase()}', AppColors.primary), const SizedBox(width: 8), _chip('⭐ ${rating.toStringAsFixed(1)}', AppColors.warning), const SizedBox(width: 8), _chip('$trips trips', AppColors.success)]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (isOnline ? AppColors.success : Colors.grey.shade400).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(isOnline ? 'ONLINE' : 'OFFLINE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? AppColors.success : Colors.grey.shade600))),
              const SizedBox(height: 12),
              Row(children: [Text(isActive ? 'Active' : 'Inactive', style: GoogleFonts.inter(fontSize: 12, color: isActive ? AppColors.text : AppColors.subtext, fontWeight: FontWeight.w600)), const SizedBox(width: 8), Transform.scale(scale: 0.8, child: Switch.adaptive(value: isActive, activeColor: AppColors.primary, inactiveTrackColor: Colors.grey.shade200, onChanged: isSuperAdmin ? (_) => onToggleActive(rider['id'] as String, isActive) : null))]),
            ]),
          ]),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.6))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 22)),
                  const SizedBox(width: 20),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Today\'s Cash', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('৳${todayCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                  ]),
                  Container(height: 40, width: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 24)),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Due Amount', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('৳${totalCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: totalCash > 0 ? AppColors.error : AppColors.text)),
                  ]),
                ]),
                ElevatedButton.icon(
                    onPressed: totalCash > 0 ? onCollectCash : null,
                    icon: const Icon(Icons.price_check_rounded, size: 18),
                    label: Text('Collect Cash', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.border, disabledForegroundColor: AppColors.subtext, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- UPDATED ACTIONS ROW ---
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                  onPressed: onOrderHistory,
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text('Order History', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withOpacity(0.3)), backgroundColor: AppColors.primary.withOpacity(0.04), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0)
              ),
              OutlinedButton.icon(
                  onPressed: onCashHistory,
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text('Cash Logs', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: BorderSide(color: AppColors.border), backgroundColor: AppColors.surface, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0)
              ),
              OutlinedButton.icon(
                  onPressed: onCalculatePayout,
                  icon: const Icon(Icons.calculate_rounded, size: 16),
                  label: Text('Calculate Payout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6), side: const BorderSide(color: Color(0xFF8B5CF6)), backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.05), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0)
              ),
            ],
          )
        ],
      ),
    );
  }
  Widget _chip(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold)));
}

// ─── NEW: PAYOUT CALCULATOR DIALOG ──────────────────────────────────────────
class _RiderPayoutDialog extends StatefulWidget {
  final String riderId, riderName;
  const _RiderPayoutDialog({required this.riderId, required this.riderName});
  @override State<_RiderPayoutDialog> createState() => _RiderPayoutDialogState();
}

class _RiderPayoutDialogState extends State<_RiderPayoutDialog> {
  String _period = 'This Month';
  final _baseRateCtrl = TextEditingController(text: '40');
  final _batchRateCtrl = TextEditingController(text: '10');

  bool _loading = false;
  int _anchorTrips = 0;
  int _batchedTrips = 0;

  @override void initState() { super.initState(); _calculatePayout(); }

  Future<void> _calculatePayout() async {
    setState(() => _loading = true);

    DateTime now = DateTime.now();
    DateTime start, end;
    if (_period == 'Today') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_period == 'This Week') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else if (_period == 'This Month') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else { // Last Month
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
    }

    try {
      final res = await supabase.from(AppConstants.ordersTable)
          .select('id, updated_at, status, pickup_rider_id, delivery_rider_id, profiles(full_name)')
          .gte('updated_at', start.toUtc().toIso8601String())
          .lte('updated_at', end.toUtc().toIso8601String())
          .or('pickup_rider_id.eq.${widget.riderId},delivery_rider_id.eq.${widget.riderId}');

      Map<String, int> pickupGroups = {};
      Map<String, int> deliveryGroups = {};
      int totalP = 0;
      int totalD = 0;

      for (var o in res) {
        String status = o['status'] ?? '';
        if (status == 'cancelled') continue;

        String dateStr = o['updated_at'] != null ? o['updated_at'].toString().substring(0, 10) : '';
        String customerName = (o['profiles'] as Map?)?['full_name']?.toString() ?? o['id'].toString();
        String key = '${dateStr}_$customerName';

        if (o['pickup_rider_id'] == widget.riderId) {
          totalP++;
          pickupGroups[key] = (pickupGroups[key] ?? 0) + 1;
        }
        if (o['delivery_rider_id'] == widget.riderId && status == 'delivered') {
          totalD++;
          deliveryGroups[key] = (deliveryGroups[key] ?? 0) + 1;
        }
      }

      int anchors = pickupGroups.length + deliveryGroups.length;
      int batched = (totalP - pickupGroups.length) + (totalD - deliveryGroups.length);

      if (mounted) setState(() { _anchorTrips = anchors; _batchedTrips = batched; _loading = false; });
    } catch (e) {
      debugPrint("Payout Calc Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override Widget build(BuildContext context) {
    double baseRate = double.tryParse(_baseRateCtrl.text) ?? 0;
    double batchRate = double.tryParse(_batchRateCtrl.text) ?? 0;
    double totalEarned = (_anchorTrips * baseRate) + (_batchedTrips * batchRate);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 550), child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calculate_rounded, color: Color(0xFF8B5CF6), size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Earnings Calculator', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)), Text(widget.riderName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext, fontWeight: FontWeight.w500))])), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.subtext))]),
        const SizedBox(height: 24), Divider(height: 1, color: AppColors.border.withOpacity(0.5)), const SizedBox(height: 24),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Time Period', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.text)), const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _period, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20), items: ['Today', 'This Week', 'This Month', 'Last Month'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 14)))).toList(), onChanged: (v) { setState(() => _period = v!); _calculatePayout(); })))
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Base Rate (৳)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.text)), const SizedBox(height: 8),
            TextFormField(controller: _baseRateCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState((){}), decoration: InputDecoration(filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5))))
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Batch Bonus (৳)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.text)), const SizedBox(height: 8),
            TextFormField(controller: _batchRateCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState((){}), decoration: InputDecoration(filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5))))
          ])),
        ]),

        const SizedBox(height: 24),

        _loading ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())) :
        Container(
          padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Base Legs (Anchor)', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext)),
              Text('$_anchorTrips × ৳${baseRate.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Batched Extras (Same Address)', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext)),
              Text('$_batchedTrips × ৳${batchRate.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
            ]),
            const SizedBox(height: 16), Divider(height: 1, color: AppColors.border), const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total Salary Payout', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
              Text('৳${totalEarned.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
            ]),
          ]),
        ),
      ]))),
    );
  }
}

// ─── ORDER HISTORY DIALOG ────────────────────────────────────────────────
class _RiderOrderHistoryDialog extends StatefulWidget {
  final String riderId, riderName;
  const _RiderOrderHistoryDialog({required this.riderId, required this.riderName});
  @override State<_RiderOrderHistoryDialog> createState() => _RiderOrderHistoryDialogState();
}

class _RiderOrderHistoryDialogState extends State<_RiderOrderHistoryDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _sortOption = 'Newest First';

  final List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final List<int> _years = List.generate(5, (i) => DateTime.now().year - i);

  @override void initState() { super.initState(); _fetchHistory(); }

  Future<void> _fetchHistory() async {
    setState(() => _loading = true);
    try {
      final startDate = DateTime(_selectedYear, _selectedMonth, 1).toUtc().toIso8601String();
      final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59).toUtc().toIso8601String();

      final ordersRes = await supabase.from(AppConstants.ordersTable)
          .select('id, order_number, total_price, status, updated_at, pickup_rider_id, delivery_rider_id')
          .or('pickup_rider_id.eq.${widget.riderId},delivery_rider_id.eq.${widget.riderId}')
          .gte('updated_at', startDate)
          .lte('updated_at', endDate);

      final ratingsRes = await supabase.from('rider_ratings').select('order_id, stars').eq('rider_id', widget.riderId);
      final ratingsList = List<Map<String, dynamic>>.from(ratingsRes);

      List<Map<String, dynamic>> merged = [];
      for (var o in ordersRes) {
        var ratingData = ratingsList.where((r) => r['order_id'] == o['id']).toList();
        double stars = 0.0;
        if(ratingData.isNotEmpty) {
          stars = ratingData.map((e) => (e['stars'] as num).toDouble()).reduce((a, b) => a + b) / ratingData.length;
        }
        merged.add({...o, 'stars': stars});
      }

      if (_sortOption == 'Newest First') merged.sort((a,b) => (b['updated_at'] ?? '').compareTo(a['updated_at'] ?? ''));
      else if (_sortOption == 'Oldest First') merged.sort((a,b) => (a['updated_at'] ?? '').compareTo(b['updated_at'] ?? ''));
      else if (_sortOption == 'Highest Rating') merged.sort((a,b) => (b['stars'] as double).compareTo(a['stars'] as double));
      else if (_sortOption == 'Lowest Rating') merged.sort((a,b) => (a['stars'] as double).compareTo(b['stars'] as double));

      if(mounted) setState(() { _orders = merged; _loading = false; });
    } catch (e) {
      if(mounted) setState(() => _loading = false);
    }
  }

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750), child: Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Order History', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)), Text(widget.riderName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext, fontWeight: FontWeight.w500))])), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.subtext))]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _selectedMonth, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20), items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(_months[i], style: GoogleFonts.inter(fontSize: 14)))), onChanged: (v) { setState(() => _selectedMonth = v!); _fetchHistory(); })))),
          const SizedBox(width: 12),
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _selectedYear, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20), items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: GoogleFonts.inter(fontSize: 14)))).toList(), onChanged: (v) { setState(() => _selectedYear = v!); _fetchHistory(); })))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _sortOption, isExpanded: true, icon: const Icon(Icons.sort_rounded, size: 20), items: ['Newest First', 'Oldest First', 'Highest Rating', 'Lowest Rating'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 14)))).toList(), onChanged: (v) { setState(() => _sortOption = v!); _fetchHistory(); })))),
        ]),
        const SizedBox(height: 24), Divider(height: 1, color: AppColors.border.withOpacity(0.5)), const SizedBox(height: 16),

        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
            ? Center(child: Text('No completed orders in this period.', style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 14)))
            : ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final o = _orders[i];
              final status = o['status'] ?? '';
              bool picked = o['pickup_rider_id'] == widget.riderId;
              bool deliv = o['delivery_rider_id'] == widget.riderId;
              String tag = status == 'delivered' ? (picked && deliv ? 'ROUND TRIP' : picked ? 'PICKUP ONLY' : 'DELIVERY ONLY') : status.toUpperCase();
              String dateStr = '';
              if (o['updated_at'] != null) {
                final d = DateTime.parse(o['updated_at']).toLocal();
                dateStr = '${d.day} ${_months[d.month-1]} ${d.year}';
              }
              double stars = o['stars'] ?? 0.0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border.withOpacity(0.6))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${o['order_number']}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: ShapeDecoration(shape: const StadiumBorder(), color: AppColors.primary.withOpacity(0.08)), child: Text(tag, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary))),
                      const SizedBox(width: 10),
                      Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)),
                    ])
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('৳${((o['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 6),
                    if (stars > 0) Row(children: [const Icon(Icons.star_rounded, color: AppColors.warning, size: 14), const SizedBox(width: 4), Text(stars.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning))])
                    else Text('No Rating', style: GoogleFonts.inter(fontSize: 11, color: AppColors.subtext)),
                  ])
                ]),
              );
            }
        )
        )
      ]))),
    );
  }
}

// ─── CASH SUBMISSION HISTORY DIALOG ──────────────────────────────────────
class _RiderCashHistoryDialog extends StatefulWidget {
  final String riderId, riderName;
  const _RiderCashHistoryDialog({required this.riderId, required this.riderName});
  @override State<_RiderCashHistoryDialog> createState() => _RiderCashHistoryDialogState();
}

class _RiderCashHistoryDialogState extends State<_RiderCashHistoryDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _submissions = [];
  final List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override void initState() { super.initState(); _fetchCashHistory(); }

  Future<void> _fetchCashHistory() async {
    try {
      final res = await supabase.from('rider_cash_submissions')
          .select()
          .eq('rider_id', widget.riderId)
          .order('submitted_at', ascending: false);

      if(mounted) setState(() { _submissions = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (e) {
      if(mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600), child: Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.history_rounded, color: AppColors.success, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Cash Logs', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)), Text(widget.riderName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext, fontWeight: FontWeight.w500))])), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.subtext))]),
        const SizedBox(height: 24), Divider(height: 1, color: AppColors.border.withOpacity(0.5)), const SizedBox(height: 16),

        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('Database Error:\n$_error', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)))
            : _submissions.isEmpty
            ? Center(child: Text('No cash submissions found.', style: GoogleFonts.inter(color: AppColors.subtext)))
            : ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _submissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final sub = _submissions[i];
              String dateStr = ''; String timeStr = '';
              if (sub['submitted_at'] != null) {
                final d = DateTime.parse(sub['submitted_at']).toLocal();
                dateStr = '${d.day} ${_months[d.month-1]} ${d.year}';
                timeStr = '${d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour)}:${d.minute.toString().padLeft(2,'0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border.withOpacity(0.6))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: const Icon(Icons.monetization_on_rounded, color: AppColors.success, size: 18)),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cash Collected', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text('$dateStr • $timeStr', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext)),
                    ])
                  ]),
                  Text('৳${((sub['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
                ]),
              );
            }
        )
        )
      ]))),
    );
  }
}

// ─── COLLECT CASH DIALOG ────────────────────────────────────────────────
class _CollectCashDialog extends StatefulWidget {
  final String riderId, riderName; final double todayCash, totalCash; final VoidCallback onSuccess;
  const _CollectCashDialog({required this.riderId, required this.riderName, required this.todayCash, required this.totalCash, required this.onSuccess});
  @override State<_CollectCashDialog> createState() => _CollectCashDialogState();
}

class _CollectCashDialogState extends State<_CollectCashDialog> {
  final _amtCtrl = TextEditingController();
  bool _loading = false; String? _error;

  @override void initState() { super.initState(); _amtCtrl.text = widget.totalCash.toStringAsFixed(0); }

  Future<void> _sendNotificationToRider(String targetRiderId, double amount) async {
    const String oneSignalAppId = ApiKeys.oneSignalAppId; const String oneSignalRestApiKey = ApiKeys.oneSignalRestKey;
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: { 'Content-Type': 'application/json; charset=utf-8', 'Authorization': 'Basic $oneSignalRestApiKey', },
        body: jsonEncode({ 'app_id': oneSignalAppId, 'target_channel': 'push', 'include_aliases': { 'external_id': [targetRiderId] }, 'headings': {'en': 'Cash Collected! 💵'}, 'contents': {'en': 'Submitted In Hand Cash: ৳${amount.toStringAsFixed(0)} Successfully'}, }),
      );
      final res = jsonDecode(response.body); if (res.containsKey('errors')) debugPrint('OneSignal Error: ${res['errors']}');
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _submitCash() async {
    final amt = double.tryParse(_amtCtrl.text);
    if (amt == null || amt <= 0) { setState(() => _error = 'Enter a valid amount'); return; }
    if (amt > widget.totalCash) { setState(() => _error = 'Cannot collect more than Total Due (৳${widget.totalCash})'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      await supabase.rpc('collect_rider_cash', params: { 'p_rider_id': widget.riderId, 'p_amount': amt, });
      await _sendNotificationToRider(widget.riderId, amt);
      widget.onSuccess(); if (mounted) Navigator.pop(context);
    } catch (e) { setState(() { _loading = false; _error = e.toString(); }); }
  }

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.monetization_on_rounded, color: AppColors.success, size: 24)), const SizedBox(width: 16), Text('Collect Cash', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.subtext))]),
        const SizedBox(height: 24), Text('Collecting from ${widget.riderName}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext, fontWeight: FontWeight.w500)), const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [Text('Today\'s Cash', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text('৳${widget.todayCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text))]),
            Container(width: 1, height: 40, color: AppColors.border),
            Column(children: [Text('Total Due', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text('৳${widget.totalCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error))]),
          ]),
        ),
        const SizedBox(height: 24), Text('Amount to Collect (৳)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text)), const SizedBox(height: 8),
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: Icon(Icons.payments_rounded, color: AppColors.subtext), filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.success, width: 1.5)))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)))),
        const SizedBox(height: 32), SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : _submitCash, style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text('Confirm Collection', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}

class _RiderFormDialog extends StatefulWidget {
  final VoidCallback onSaved; final Map<String, dynamic>? rider; const _RiderFormDialog({required this.onSaved, this.rider});
  @override State<_RiderFormDialog> createState() => _RiderFormDialogState();
}

class _RiderFormDialogState extends State<_RiderFormDialog> {
  final _formKey = GlobalKey<FormState>(); final _nameCtrl = TextEditingController(); final _phoneCtrl = TextEditingController(); final _passwordCtrl = TextEditingController(); final _plateCtrl = TextEditingController();
  bool _loading = false; String _selectedVehicle = 'motorcycle'; final List<String> _vehicleTypes = ['motorcycle', 'bicycle', 'car', 'van'];
  Uint8List? _avatarBytes; String? _existingAvatarUrl;

  bool _obscurePassword = true;

  @override void initState() {
    super.initState();
    if (widget.rider != null) {
      _nameCtrl.text = widget.rider!['full_name'] ?? '';
      _phoneCtrl.text = widget.rider!['phone'] ?? '';
      _passwordCtrl.text = widget.rider!['password'] ?? '';
      _plateCtrl.text = widget.rider!['vehicle_plate'] ?? '';
      _selectedVehicle = widget.rider!['vehicle_type'] ?? 'motorcycle';
      _existingAvatarUrl = widget.rider!['avatar_url'];
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker(); final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) { final bytes = await image.readAsBytes(); setState(() => _avatarBytes = bytes); }
  }

  String _generateUuid() {
    final random = Random.secure(); final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final chars = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${chars.substring(0, 8)}-${chars.substring(8, 12)}-${chars.substring(12, 16)}-${chars.substring(16, 20)}-${chars.substring(20, 32)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    String plateValue = _plateCtrl.text.trim(); if (_selectedVehicle == 'bicycle' && plateValue.isEmpty) plateValue = 'N/A';
    try {
      String? finalAvatarUrl = _existingAvatarUrl;
      if (_avatarBytes != null) {
        final adminId = supabase.auth.currentUser!.id; final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg'; final storagePath = '$adminId/$fileName';
        await supabase.storage.from('avatars').uploadBinary(storagePath, _avatarBytes!, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
        finalAvatarUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
      }

      final Map<String, dynamic> riderData = {
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'vehicle_type': _selectedVehicle,
        'vehicle_plate': plateValue,
        'avatar_url': finalAvatarUrl
      };

      if (widget.rider == null) {
        riderData['id'] = _generateUuid(); riderData['is_active'] = true; riderData['is_online'] = false; riderData['rating'] = 5.0; riderData['total_trips'] = 0; riderData['cash_in_hand'] = 0;
        await supabase.from(AppConstants.ridersTable).insert(riderData);
      } else {
        await supabase.from(AppConstants.ridersTable).update(riderData).eq('id', widget.rider!['id']);
      }
      widget.onSaved(); if (mounted) Navigator.pop(context);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error)); }
    setState(() => _loading = false);
  }

  InputDecoration _deco(String hint, {Widget? suffixIcon}) => InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.subtext, fontSize: 14), filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)), suffixIcon: suffixIcon);
  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text)));

  @override Widget build(BuildContext context) {
    final isBicycle = _selectedVehicle == 'bicycle'; final isEditMode = widget.rider != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540), child: Padding(padding: const EdgeInsets.all(32), child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isEditMode ? Icons.edit_document : Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 24)), const SizedBox(width: 16), Text(isEditMode ? 'Edit Rider' : 'Add New Rider', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: AppColors.subtext))]),
        const SizedBox(height: 24), Divider(height: 1, color: AppColors.border.withOpacity(0.5)), const SizedBox(height: 24),
        GestureDetector(onTap: _pickImage, child: Stack(children: [CircleAvatar(radius: 56, backgroundColor: AppColors.background, backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty ? NetworkImage(_existingAvatarUrl!) as ImageProvider : null), child: (_avatarBytes == null && (_existingAvatarUrl == null || _existingAvatarUrl!.isEmpty)) ? Icon(Icons.add_a_photo_rounded, color: AppColors.subtext, size: 32) : null), Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2.5)), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14)))])),
        const SizedBox(height: 32),
        _label('Rider Full Name *'), TextFormField(controller: _nameCtrl, decoration: _deco('Enter rider name'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null), const SizedBox(height: 20),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Phone Number *'), TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _deco('Enter phone number'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null)])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Assign Password *'),
            TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: _deco(
                    'Create password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.subtext, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    )
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null
            )
          ]))
        ]),
        const SizedBox(height: 20),

        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Vehicle Type'), DropdownButtonFormField<String>(value: _selectedVehicle, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20), items: _vehicleTypes.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: GoogleFonts.inter(fontSize: 14)))).toList(), onChanged: (v) => setState(() => _selectedVehicle = v!), decoration: _deco(''))])), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(isBicycle ? 'Vehicle Plate (Optional)' : 'Vehicle Plate *'), TextFormField(controller: _plateCtrl, decoration: _deco(isBicycle ? 'Leave blank for N/A' : 'e.g. DHK-1234'), validator: (v) => (!isBicycle && (v?.trim().isEmpty ?? true)) ? 'Required' : null)]))]),
        const SizedBox(height: 32), Divider(height: 1, color: AppColors.border.withOpacity(0.5)), const SizedBox(height: 24),
        Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), side: BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 15)))), const SizedBox(width: 16), Expanded(child: _GradientButton(label: _loading ? 'Saving…' : (isEditMode ? 'Update Rider' : 'Add Rider'), icon: Icons.check_rounded, onPressed: _loading ? null : _submit))]),
      ]))))),
    );
  }
}
class _GradientButton extends StatelessWidget {
  final String label; final IconData? icon; final VoidCallback? onPressed;
  const _GradientButton({required this.label, this.icon, required this.onPressed});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: onPressed != null ? AppColors.gradient : null, color: onPressed == null ? AppColors.border : null, borderRadius: BorderRadius.circular(12), boxShadow: onPressed != null ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : []), child: ElevatedButton.icon(onPressed: onPressed, icon: icon != null ? Icon(icon, color: Colors.white, size: 20) : const SizedBox.shrink(), label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
}