// lib/features/home/riders_screen.dart
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

  // Stores "Today's Cash" calculation for each rider
  Map<String, double> _todayCashMap = {};

  @override void initState() { super.initState(); _loadRidersData(); }

  Future<void> _loadRidersData() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch all riders
      final data = await supabase.from(AppConstants.ridersTable).select().order('created_at', ascending: false);

      // 2. Fetch today's delivered orders to calculate "Today's Cash" dynamically
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

  Future<void> _toggleActive(String riderId, bool current) async { await supabase.from(AppConstants.ridersTable).update({'is_active': !current}).eq('id', riderId); _loadRidersData(); }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchQuery.toLowerCase(); if (q.isEmpty) return _riders;
    return _riders.where((r) => (r['full_name'] ?? '').toString().toLowerCase().contains(q) || (r['phone'] ?? '').toString().toLowerCase().contains(q) || (r['vehicle_plate'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  void _showRiderForm([Map<String, dynamic>? rider]) => showDialog(context: context, builder: (_) => _RiderFormDialog(onSaved: _loadRidersData, rider: rider));

  void _showCollectCashDialog(String riderId, String riderName, double todayCash, double totalCash) {
    showDialog(context: context, builder: (_) => _CollectCashDialog(
        riderId: riderId,
        riderName: riderName,
        todayCash: todayCash,
        totalCash: totalCash,
        onSuccess: _loadRidersData
    ));
  }

  @override Widget build(BuildContext context) {
    final online = _riders.where((r) => r['is_online'] == true).length; final active = _riders.where((r) => r['is_active'] == true).length;

    return Column(children: [
      Container(
        height: 72, padding: const EdgeInsets.symmetric(horizontal: 32), decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Riders', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)), Text('${_riders.length} total  •  $online online  •  $active active', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext))]),
          const Spacer(),

          if (widget.isSuperAdmin) ...[
            _GradientButton(label: 'Add Rider', icon: Icons.add, onPressed: () => _showRiderForm()),
            const SizedBox(width: 16),
          ],

          Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.text), onPressed: _loadRidersData)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _RiderStat('Total Riders', _riders.length.toString(), AppColors.primary, Icons.people_outlined), const SizedBox(width: 16),
              _RiderStat('Online Now', online.toString(), AppColors.success, Icons.wifi_outlined), const SizedBox(width: 16),
              _RiderStat('Active Accounts', active.toString(), AppColors.info, Icons.check_circle_outline), const SizedBox(width: 16),
              _RiderStat('Offline', (active - online).toString(), AppColors.subtext, Icons.wifi_off_outlined),
            ]),
            const SizedBox(height: 24),
            TextField(onChanged: (v) => setState(() => _searchQuery = v), style: GoogleFonts.inter(fontSize: 15), decoration: InputDecoration(hintText: 'Search by name, phone, plate…', hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14), prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 22), filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)))),
            const SizedBox(height: 24),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : _filtered.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delivery_dining, size: 64, color: AppColors.border), const SizedBox(height: 16), Text('No riders found', style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 16))])) : ListView.separated(physics: const BouncingScrollPhysics(), itemCount: _filtered.length, separatorBuilder: (_, __) => const SizedBox(height: 16), itemBuilder: (_, i) {
              final r = _filtered[i];
              final rId = r['id'] as String;
              return _RiderCard(
                rider: r,
                isSuperAdmin: widget.isSuperAdmin,
                todayCash: _todayCashMap[rId] ?? 0.0,
                onToggleActive: _toggleActive,
                onEdit: () => _showRiderForm(r),
                onCollectCash: () => _showCollectCashDialog(rId, r['full_name'] ?? 'Rider', _todayCashMap[rId] ?? 0.0, (r['cash_in_hand'] as num?)?.toDouble() ?? 0.0),
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
  @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)), Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500))])])));
}

class _RiderCard extends StatelessWidget {
  final Map<String, dynamic> rider; final bool isSuperAdmin; final double todayCash;
  final Future<void> Function(String, bool) onToggleActive; final VoidCallback onEdit; final VoidCallback onCollectCash;
  const _RiderCard({required this.rider, required this.isSuperAdmin, required this.todayCash, required this.onToggleActive, required this.onEdit, required this.onCollectCash});

  String _vehicleEmoji(String t) { switch (t) { case 'motorcycle': return '🏍️'; case 'bicycle': return '🚲'; case 'van': return '🚐'; default: return '🚗'; } }

  @override Widget build(BuildContext context) {
    final isOnline = rider['is_online'] == true; final isActive = rider['is_active'] == true; final name = rider['full_name'] as String? ?? 'Rider'; final vehicle = rider['vehicle_type'] as String? ?? 'motorcycle'; final plate = rider['vehicle_plate'] as String? ?? 'No plate'; final phone = rider['phone'] as String? ?? '—'; final rating = (rider['rating'] as num?)?.toDouble() ?? 5.0; final trips = rider['total_trips'] as int? ?? 0; final avatar = rider['avatar_url'] as String?;
    final totalCash = (rider['cash_in_hand'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Row(children: [
            Stack(children: [CircleAvatar(radius: 28, backgroundColor: AppColors.background, backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null, child: (avatar == null || avatar.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'R', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)) : null), Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: isOnline ? AppColors.success : Colors.grey.shade400, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5))))]),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)), const SizedBox(width: 12),
                if (isSuperAdmin) GestureDetector(onTap: onEdit, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.edit_square, color: AppColors.primary, size: 16)))
              ]),
              const SizedBox(height: 6), Text('$phone  •  $plate', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext)), const SizedBox(height: 8),
              Row(children: [_chip('${_vehicleEmoji(vehicle)} $vehicle', AppColors.primary), const SizedBox(width: 8), _chip('⭐ ${rating.toStringAsFixed(1)}', AppColors.warning), const SizedBox(width: 8), _chip('$trips trips', AppColors.success)]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isOnline ? AppColors.success : Colors.grey.shade400).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(isOnline ? 'Online' : 'Offline', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isOnline ? AppColors.success : Colors.grey.shade500))),
              const SizedBox(height: 8), Transform.scale(scale: 0.85, child: Switch.adaptive(value: isActive, activeColor: AppColors.primary, onChanged: isSuperAdmin ? (_) => onToggleActive(rider['id'] as String, isActive) : null)), Text(isActive ? 'Active' : 'Inactive', style: GoogleFonts.inter(fontSize: 11, color: AppColors.subtext, fontWeight: FontWeight.w500)),
            ]),
          ]),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // CASH TRACKING UI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green, size: 20)),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today\'s Cash', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)),
                  Text('৳${todayCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                ]),
                const SizedBox(width: 32),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Due Amount', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext, fontWeight: FontWeight.w500)),
                  Text('৳${totalCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: totalCash > 0 ? Colors.red.shade600 : AppColors.text)),
                ]),
              ]),
              ElevatedButton.icon(
                  onPressed: totalCash > 0 ? onCollectCash : null,
                  icon: const Icon(Icons.price_check_rounded, size: 18),
                  label: Text('Collect Cash', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, disabledForegroundColor: Colors.grey.shade500, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))
              )
            ],
          )
        ],
      ),
    );
  }
  Widget _chip(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.bold)));
}

// ─── NEW COLLECT CASH DIALOG ──────────────────────────────────────────────────
class _CollectCashDialog extends StatefulWidget {
  final String riderId, riderName; final double todayCash, totalCash; final VoidCallback onSuccess;
  const _CollectCashDialog({required this.riderId, required this.riderName, required this.todayCash, required this.totalCash, required this.onSuccess});
  @override State<_CollectCashDialog> createState() => _CollectCashDialogState();
}
class _CollectCashDialogState extends State<_CollectCashDialog> {
  final _amtCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.totalCash.toStringAsFixed(0);
  }

  // ─── NEW: ONESIGNAL PUSH NOTIFICATION LOGIC ───
  // ─── UPDATED: ONESIGNAL PUSH NOTIFICATION LOGIC ───
  Future<void> _sendNotificationToRider(String targetRiderId, double amount) async {
    // ⚠️ Replace these with your actual keys!
    const String oneSignalAppId = 'ccdfa117-940d-41fc-8a59-f2043aa3cee8';
    const String oneSignalRestApiKey = 'os_v2_app_ztp2cf4ubva7zcsz6icdvi6o5asewcb76ebu635iy7dfowxboz2d2635ryw4olzn6ha3ujufruufldiuprvkqxydjo56jcoh5bs7yma';

    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $oneSignalRestApiKey',
        },
        body: jsonEncode({
          'app_id': oneSignalAppId,
          'target_channel': 'push',
          // Matching your Deno Edge Function exactly!
          'include_aliases': {
            'external_id': [targetRiderId]
          },
          'headings': {'en': '💵 Cash Collected!'},
          // Matching the exact text you requested
          'contents': {'en': 'Submitted In Hand Cash: ৳${amount.toStringAsFixed(0)} Successfully'},
        }),
      );
      debugPrint('Notification sent successfully to Rider: $targetRiderId');
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  Future<void> _submitCash() async {
    final amt = double.tryParse(_amtCtrl.text);
    if (amt == null || amt <= 0) { setState(() => _error = 'Enter a valid amount'); return; }
    if (amt > widget.totalCash) { setState(() => _error = 'Cannot collect more than Total Due (৳${widget.totalCash})'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      // 1. Log transaction & deduct from database
      await supabase.rpc('collect_rider_cash', params: {
        'p_rider_id': widget.riderId,
        'p_amount': amt,
      });

      // 2. SEND INSTANT PUSH NOTIFICATION
      await _sendNotificationToRider(widget.riderId, amt);

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _loading = false; _error = 'Database Error: $e'; });
    }
  }

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.monetization_on_rounded, color: Colors.green, size: 24)), const SizedBox(width: 16), Text('Collect Cash', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.subtext))]),
        const SizedBox(height: 24),
        Text('Collecting from ${widget.riderName}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.subtext)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [Text('Today\'s Cash', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext)), const SizedBox(height: 4), Text('৳${widget.todayCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text))]),
            Container(width: 1, height: 40, color: AppColors.border),
            Column(children: [Text('Total Due', style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext)), const SizedBox(height: 4), Text('৳${widget.totalCash.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade600))]),
          ]),
        ),
        const SizedBox(height: 24),
        Text('Amount to Collect (৳)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text)), const SizedBox(height: 8),
        TextField(controller: _amtCtrl, keyboardType: TextInputType.number, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: const Icon(Icons.payments_outlined, color: Colors.grey), filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green, width: 2)))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: GoogleFonts.inter(color: Colors.red, fontSize: 12))),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : _submitCash, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text('Confirm Collection', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────────

class _RiderFormDialog extends StatefulWidget {
  final VoidCallback onSaved; final Map<String, dynamic>? rider; const _RiderFormDialog({required this.onSaved, this.rider});
  @override State<_RiderFormDialog> createState() => _RiderFormDialogState();
}

class _RiderFormDialogState extends State<_RiderFormDialog> {
  final _formKey = GlobalKey<FormState>(); final _nameCtrl = TextEditingController(); final _phoneCtrl = TextEditingController(); final _plateCtrl = TextEditingController();
  bool _loading = false; String _selectedVehicle = 'motorcycle'; final List<String> _vehicleTypes = ['motorcycle', 'bicycle', 'car', 'van'];
  Uint8List? _avatarBytes; String? _existingAvatarUrl;

  @override void initState() {
    super.initState();
    if (widget.rider != null) { _nameCtrl.text = widget.rider!['full_name'] ?? ''; _phoneCtrl.text = widget.rider!['phone'] ?? ''; _plateCtrl.text = widget.rider!['vehicle_plate'] ?? ''; _selectedVehicle = widget.rider!['vehicle_type'] ?? 'motorcycle'; _existingAvatarUrl = widget.rider!['avatar_url']; }
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
      final Map<String, dynamic> riderData = {'full_name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(), 'vehicle_type': _selectedVehicle, 'vehicle_plate': plateValue, 'avatar_url': finalAvatarUrl};
      if (widget.rider == null) { riderData['id'] = _generateUuid(); riderData['is_active'] = true; riderData['is_online'] = false; riderData['rating'] = 5.0; riderData['total_trips'] = 0; riderData['cash_in_hand'] = 0; await supabase.from(AppConstants.ridersTable).insert(riderData); }
      else { await supabase.from(AppConstants.ridersTable).update(riderData).eq('id', widget.rider!['id']); }
      widget.onSaved(); if (mounted) Navigator.pop(context);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error)); }
    setState(() => _loading = false);
  }

  InputDecoration _deco(String hint) => InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14), filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)));
  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text)));

  @override Widget build(BuildContext context) {
    final isBicycle = _selectedVehicle == 'bicycle'; final isEditMode = widget.rider != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: AppColors.surface,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Padding(padding: const EdgeInsets.all(32), child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isEditMode ? Icons.edit_document : Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 24)), const SizedBox(width: 16), Text(isEditMode ? 'Edit Rider' : 'Add New Rider', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.subtext))]),
        const SizedBox(height: 24), const Divider(height: 1), const SizedBox(height: 24),
        GestureDetector(onTap: _pickImage, child: Stack(children: [CircleAvatar(radius: 56, backgroundColor: AppColors.background, backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty ? NetworkImage(_existingAvatarUrl!) as ImageProvider : null), child: (_avatarBytes == null && (_existingAvatarUrl == null || _existingAvatarUrl!.isEmpty)) ? Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 36) : null), Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16)))])),
        const SizedBox(height: 32),
        _label('Rider Full Name *'), TextFormField(controller: _nameCtrl, decoration: _deco('Enter rider name'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null), const SizedBox(height: 20),
        _label('Phone Number *'), TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _deco('Enter phone number'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null), const SizedBox(height: 20),
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Vehicle Type'), DropdownButtonFormField<String>(value: _selectedVehicle, items: _vehicleTypes.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: GoogleFonts.inter(fontSize: 14)))).toList(), onChanged: (v) => setState(() => _selectedVehicle = v!), decoration: _deco(''))])), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label(isBicycle ? 'Vehicle Plate (Optional)' : 'Vehicle Plate *'), TextFormField(controller: _plateCtrl, decoration: _deco(isBicycle ? 'Leave blank for N/A' : 'e.g. DHK-1234'), validator: (v) => (!isBicycle && (v?.trim().isEmpty ?? true)) ? 'Required' : null)]))]),
        const SizedBox(height: 32), const Divider(height: 1), const SizedBox(height: 24),
        Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 15)))), const SizedBox(width: 16), Expanded(child: _GradientButton(label: _loading ? 'Saving…' : (isEditMode ? 'Update Rider' : 'Add Rider'), icon: Icons.check, onPressed: _loading ? null : _submit))]),
      ]))))),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label; final IconData? icon; final VoidCallback? onPressed;
  const _GradientButton({required this.label, this.icon, required this.onPressed});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: onPressed != null ? AppColors.gradient : null, color: onPressed == null ? AppColors.border : null, borderRadius: BorderRadius.circular(12), boxShadow: onPressed != null ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : []), child: ElevatedButton.icon(onPressed: onPressed, icon: icon != null ? Icon(icon, color: Colors.white, size: 20) : const SizedBox.shrink(), label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))));
}