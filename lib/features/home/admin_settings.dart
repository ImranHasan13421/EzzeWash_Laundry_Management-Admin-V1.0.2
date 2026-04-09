// lib/features/home/admin_settings.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';

// --- DYNAMIC THEME HELPERS ---
bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
Color _bgColor(BuildContext context) => _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
Color _surfaceColor(BuildContext context) => _isDark(context) ? const Color(0xFF1E293B) : Colors.white;
Color _textColor(BuildContext context) => _isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
Color _subtextColor(BuildContext context) => _isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
Color _borderColor(BuildContext context) => _isDark(context) ? const Color(0xFF475569) : const Color(0xFFE2E8F0);

class SettingsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final String? managerStoreId;
  const SettingsScreen({super.key, required this.isSuperAdmin, this.managerStoreId});

  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;
  bool _loading = false;
  bool _isSaving = false;
  bool _isInviting = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _bizNameCtrl = TextEditingController();
  final _bizGstCtrl = TextEditingController();
  final _bizAddrCtrl = TextEditingController();
  final _bizPhoneCtrl = TextEditingController();

  final _inviteEmailCtrl = TextEditingController();
  String _inviteRole = 'Manager';
  String? _inviteStoreId;

  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _storesList = [];
  List<Map<String, dynamic>> _servicesList = [];
  List<Map<String, dynamic>> _customersList = [];
  String _customerSearchQuery = '';

  User? currentUser;
  String _joinedDate = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      _nameCtrl.text = currentUser!.userMetadata?['full_name'] as String? ?? (widget.isSuperAdmin ? 'MD. Imran Hasan' : 'Manager');
      _phoneCtrl.text = currentUser!.userMetadata?['phone'] as String? ?? '';
      _emailCtrl.text = currentUser!.email ?? 'imranhasan13421@gmail.com';
      final createdAt = DateTime.tryParse(currentUser!.createdAt);
      if (createdAt != null) {
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        _joinedDate = '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
      }
    }

    await Future.wait([
      _loadBusinessSettings(),
      if (widget.isSuperAdmin) _loadStores(),
      if (widget.isSuperAdmin) _loadTeamMembers(),
      if (widget.isSuperAdmin) _loadServices(),
      if (widget.isSuperAdmin) _loadCustomers(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBusinessSettings() async {
    try {
      final data = await Supabase.instance.client.from('settings').select().eq('id', 1).maybeSingle();
      if (data != null) {
        _bizNameCtrl.text = data['business_name'] ?? '';
        _bizGstCtrl.text = data['gst_number'] ?? '';
        _bizAddrCtrl.text = data['business_address'] ?? '';
        _bizPhoneCtrl.text = data['contact_number'] ?? '';
      }
    } catch (e) { debugPrint('Error loading business settings: $e'); }
  }

  Future<void> _loadStores() async {
    try {
      final data = await Supabase.instance.client.from('stores').select().order('created_at', ascending: false);
      if (mounted) setState(() => _storesList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error loading stores: $e'); }
  }

  Future<void> _loadTeamMembers() async {
    try {
      final data = await Supabase.instance.client.from('team_members').select('*, stores(name, city)').order('created_at');
      if (mounted) setState(() => _teamMembers = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error loading team: $e'); }
  }

  Future<void> _loadServices() async {
    try {
      final data = await Supabase.instance.client.from('services').select().order('created_at', ascending: false);
      if (mounted) setState(() => _servicesList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error loading services: $e'); }
  }

  Future<void> _loadCustomers() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select().order('created_at', ascending: false);
      if (mounted) setState(() => _customersList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error loading customers: $e'); }
  }

  Future<void> _toggleServiceStatus(Map<String, dynamic> service) async {
    final currentStatus = service['is_active'] ?? true;
    final newStatus = !currentStatus;
    try {
      await Supabase.instance.client.from('services').update({'is_active': newStatus}).eq('id', service['id']);
      _loadServices();
      _showToast(newStatus ? '${service['title']} is now Available' : '${service['title']} is now Unavailable', newStatus ? AppColors.success : AppColors.warning);
    } catch (e) { _showToast('Error updating status: $e', AppColors.error); }
  }

  Future<void> _toggleStoreStatus(Map<String, dynamic> store) async {
    final currentStatus = store['is_active'] ?? true;
    final newStatus = !currentStatus;
    try {
      await Supabase.instance.client.from('stores').update({'is_active': newStatus}).eq('id', store['id']);
      _loadStores();
      _showToast(newStatus ? '${store['name']} is now Open' : '${store['name']} is now Closed', newStatus ? AppColors.success : AppColors.warning);
    } catch (e) { _showToast('Error updating store status: $e', AppColors.error); }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'profile', 'name': 'Profile', 'icon': Icons.person_outline},
      {'id': 'security', 'name': 'Security', 'icon': Icons.shield_outlined},
      if (widget.isSuperAdmin) {'id': 'team', 'name': 'Team', 'icon': Icons.people_outline},
      if (widget.isSuperAdmin) {'id': 'customers', 'name': 'Customers', 'icon': Icons.manage_accounts_outlined},
      if (widget.isSuperAdmin) {'id': 'stores', 'name': 'Stores', 'icon': Icons.store_mall_directory_outlined},
      if (widget.isSuperAdmin) {'id': 'services', 'name': 'Services', 'icon': Icons.dry_cleaning_outlined},
      if (widget.isSuperAdmin) {'id': 'business', 'name': 'Business', 'icon': Icons.business_center_outlined},
    ];

    if (_tab >= tabs.length) _tab = 0;

    return Container(
      color: _bgColor(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 72, padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(color: _surfaceColor(context), border: Border(bottom: BorderSide(color: _borderColor(context), width: 1.5))),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Settings', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: _textColor(context))),
              Text('Manage your account, team, stores, and business preferences', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
            ]),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0).withOpacity(0.7), borderRadius: BorderRadius.circular(14)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(tabs.length, (i) {
                    final sel = _tab == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() { _tab = i; _isInviting = false; });
                        if (tabs[i]['id'] == 'team') _loadTeamMembers();
                        if (tabs[i]['id'] == 'customers') _loadCustomers();
                        if (tabs[i]['id'] == 'stores') _loadStores();
                        if (tabs[i]['id'] == 'services') _loadServices();
                        if (tabs[i]['id'] == 'business') _loadBusinessSettings();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                            color: sel ? _surfaceColor(context) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 2))] : []
                        ),
                        child: Row(children: [
                          Icon(tabs[i]['icon'] as IconData, size: 18, color: sel ? AppColors.primary : _subtextColor(context)),
                          const SizedBox(width: 8),
                          Text(tabs[i]['name'] as String, style: GoogleFonts.inter(color: sel ? _textColor(context) : _subtextColor(context), fontWeight: sel ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
                        ]),
                      ),
                    );
                  })),
                ),
              ),
              const SizedBox(height: 32),

              if (tabs[_tab]['id'] == 'profile') _profileTab(),
              if (tabs[_tab]['id'] == 'security') _securityTab(),
              if (tabs[_tab]['id'] == 'team') _teamTab(),
              if (tabs[_tab]['id'] == 'customers') _customersTab(),
              if (tabs[_tab]['id'] == 'stores') _storesTab(),
              if (tabs[_tab]['id'] == 'services') _servicesTab(),
              if (tabs[_tab]['id'] == 'business') _businessTab(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _profileTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionCard(
          title: 'Profile Information',
          icon: Icons.person_outline,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(gradient: AppColors.gradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(child: Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U', style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 24),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nameCtrl.text, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor(context))),
                const SizedBox(height: 2),
                Text(_emailCtrl.text, style: GoogleFonts.inter(fontSize: 15, color: _subtextColor(context))),
                const SizedBox(height: 8),
                _roleBadge(widget.isSuperAdmin ? 'Super Admin' : 'Manager'),
              ])
            ]),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: _textField('Full Name', _nameCtrl)),
              const SizedBox(width: 24),
              Expanded(child: _textField('Phone Number', _phoneCtrl, hint: '+8801XXXXXXXXX')),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _textField('Role', TextEditingController(text: widget.isSuperAdmin ? 'Super Admin' : 'Manager'), readOnly: true)),
              const SizedBox(width: 24),
              Expanded(child: _textField('Joined', TextEditingController(text: _joinedDate), readOnly: true)),
            ]),
            const SizedBox(height: 32),
            _actionButton('Save Changes', AppColors.primary, Icons.save_rounded, () async {
              setState(() => _isSaving = true);
              try {
                await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'full_name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()}));
                _showToast('Profile updated successfully!', AppColors.success);
              } catch (e) {
                _showToast('Error updating profile: $e', AppColors.error);
              }
              setState(() => _isSaving = false);
            }),
          ])
      ),
      const SizedBox(height: 24),
      _sectionCard(
        title: 'Appearance',
        icon: Icons.dark_mode_outlined,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor(context))),
                const SizedBox(height: 4),
                Text('Adjust the app theme to your preference', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context))),
              ],
            ),
            Switch.adaptive(
              value: darkModeNotifier.value,
              activeColor: AppColors.primary,
              onChanged: (val) {
                setState(() {
                  darkModeNotifier.value = val;
                });
              },
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _securityTab() {
    return _sectionCard(
        title: 'Security',
        icon: Icons.shield_outlined,
        iconColor: AppColors.accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _textField('Change Name', _nameCtrl, hint: 'Update your name')),
            const SizedBox(width: 24),
            Expanded(child: _textField('Change Password', _passCtrl, hint: 'Update your account password', obscure: true)),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _textField('Change Email Address', _emailCtrl, hint: 'Current: ${_emailCtrl.text}')),
            const SizedBox(width: 24),
            Expanded(child: _textField('Change Phone Number', _phoneCtrl, hint: '+880xxxxxxxxxx')),
          ]),
          const SizedBox(height: 32),
          _actionButton('Save Security Settings', AppColors.primary, Icons.lock_outline_rounded, () async {
            setState(() => _isSaving = true);
            try {
              if (_passCtrl.text.isNotEmpty && _passCtrl.text.length >= 6) {
                await Supabase.instance.client.auth.updateUser(UserAttributes(password: _passCtrl.text.trim()));
              }
              await Supabase.instance.client.auth.updateUser(UserAttributes(email: _emailCtrl.text.trim(), data: {'full_name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()}));
              _passCtrl.clear();
              _showToast('Security settings updated!', AppColors.success);
            } catch (e) {
              _showToast('Error: $e', AppColors.error);
            }
            setState(() => _isSaving = false);
          }),
        ])
    );
  }

  // ─── CUSTOMERS TAB (View Only) ────────────────────────────────────────────────
  Widget _customersTab() {
    final filteredCustomers = _customersList.where((c) {
      if (_customerSearchQuery.isEmpty) return true;
      final q = _customerSearchQuery.toLowerCase();
      final name = (c['full_name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return _sectionCard(
      title: 'Customer Directory',
      subtitle: '${_customersList.length} registered users',
      icon: Icons.manage_accounts_outlined,
      iconColor: const Color(0xFFF59E0B),
      actionWidget: SizedBox(
        width: 300,
        child: TextField(
          onChanged: (v) => setState(() => _customerSearchQuery = v),
          style: GoogleFonts.inter(fontSize: 14, color: _textColor(context)),
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            hintStyle: GoogleFonts.inter(color: _subtextColor(context).withOpacity(0.7), fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: _subtextColor(context), size: 18),
            filled: true, fillColor: _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ),
      child: filteredCustomers.isEmpty
          ? Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text('No customers found.', style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 15))),
      )
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredCustomers.length,
        separatorBuilder: (_, __) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: _borderColor(context))),
        itemBuilder: (ctx, i) {
          final c = filteredCustomers[i];
          final name = c['full_name'] ?? 'Unknown User';
          final phone = c['phone'] ?? 'No phone';

          String dateStr = 'Unknown';
          if (c['created_at'] != null) {
            final d = DateTime.parse(c['created_at']).toLocal();
            const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            dateStr = '${d.day} ${months[d.month-1]} ${d.year}';
          }

          return Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))),
                    const SizedBox(height: 2),
                    Text(phone, style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context))),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Joined', style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context))),
                    const SizedBox(height: 2),
                    Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: _textColor(context), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCustomerOrderHistory(c),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: Text('View Orders', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- CUSTOMER ORDER HISTORY DIALOG ---
  void _showCustomerOrderHistory(Map<String, dynamic> customer) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => FutureBuilder(
        future: Supabase.instance.client
            .from('orders')
            .select('id, order_number, total_price, status, created_at')
            .eq('user_id', customer['id'])
            .order('created_at', ascending: false),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          return AlertDialog(
            backgroundColor: _surfaceColor(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))),
            title: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order History', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor(context))),
                      Text(customer['full_name'] ?? 'User', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context))),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(dialogCtx), icon: Icon(Icons.close_rounded, color: _subtextColor(context))),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                  ? Center(child: Text('Error loading orders', style: GoogleFonts.inter(color: AppColors.error)))
                  : (!snapshot.hasData || snapshot.data!.isEmpty)
                  ? Center(child: Text('No orders found for this customer.', style: GoogleFonts.inter(color: _subtextColor(context))))
                  : ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final o = snapshot.data![i];
                  String dateStr = '';
                  if (o['created_at'] != null) {
                    final d = DateTime.parse(o['created_at']).toLocal();
                    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                    dateStr = '${d.day} ${months[d.month-1]} ${d.year}';
                  }

                  Color statusColor = AppColors.primary;
                  if (o['status'] == 'delivered') statusColor = AppColors.success;
                  else if (o['status'] == 'cancelled') statusColor = AppColors.error;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor(context))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${o['order_number']}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor(context))),
                            const SizedBox(height: 4),
                            Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: _subtextColor(context))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('৳${((o['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor(context))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: ShapeDecoration(shape: const StadiumBorder(), color: statusColor.withOpacity(0.1)),
                              child: Text((o['status'] ?? 'pending').toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _teamTab() {
    return _sectionCard(
        title: 'Team Members',
        subtitle: '${_teamMembers.length + 1} members with access',
        actionWidget: ElevatedButton.icon(
          onPressed: () => setState(() => _isInviting = !_isInviting),
          icon: Icon(_isInviting ? Icons.close : Icons.person_add_outlined, color: Colors.white, size: 18),
          label: Text(_isInviting ? 'Cancel' : 'Invite Member', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2, shadowColor: AppColors.primary.withOpacity(0.5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_isInviting) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF334155).withOpacity(0.3) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor(context))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite a new team member', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor(context))),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(flex: 3, child: _textField('Email Address', _inviteEmailCtrl, hint: 'Enter email address')),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Role', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor(context))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(value: _inviteRole, icon: const Icon(Icons.keyboard_arrow_down, size: 20), items: ['Manager'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))))).toList(), onChanged: (v) => setState(() => _inviteRole = v!), decoration: _inputDeco(), dropdownColor: _surfaceColor(context)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Assign to Store', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor(context))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                          value: _inviteStoreId,
                          hint: Text('Select Store', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
                          icon: const Icon(Icons.storefront_outlined, size: 20),
                          items: _storesList.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']} (${s['city']})', style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))))).toList(),
                          onChanged: (v) => setState(() => _inviteStoreId = v),
                          decoration: _inputDeco(),
                          dropdownColor: _surfaceColor(context)
                      ),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _actionButton('Add to Whitelist', AppColors.primary, Icons.check_circle_outline, () async {
                      if (_inviteEmailCtrl.text.isEmpty || _inviteStoreId == null) {
                        _showToast('Please provide email and assign a store.', AppColors.warning);
                        return;
                      }
                      setState(() => _isSaving = true);
                      try {
                        await Supabase.instance.client.from('team_members').insert({'email': _inviteEmailCtrl.text.trim(), 'role': _inviteRole, 'store_id': _inviteStoreId});
                        _inviteEmailCtrl.clear(); _inviteStoreId = null;
                        setState(() => _isInviting = false);
                        await _loadTeamMembers();
                        _showToast('Member added to whitelist! Invite them via Supabase Dashboard.', AppColors.success);
                      } catch(e) {
                        _showToast('Error adding member: $e', AppColors.error);
                      }
                      setState(() => _isSaving = false);
                    })),
                  ]),
                  const SizedBox(height: 20),
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.info.withOpacity(0.3))), child: Row(children: [const Icon(Icons.info_outline, color: AppColors.info, size: 20), const SizedBox(width: 12), Expanded(child: Text('App Security Note: After whitelisting here, you must officially invite them via your Supabase Dashboard (Authentication -> Users -> Invite).', style: GoogleFonts.inter(fontSize: 13, color: _textColor(context))))])),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: AppColors.primary, child: Text('I', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MD. Imran Hasan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))), const SizedBox(height: 2), Text('imranhasan13421@gmail.com', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context)))])),
            Expanded(flex: 2, child: Row(children: [_roleBadge('Super Admin')])),
            Expanded(flex: 2, child: Text('Global Access', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold))),
            const SizedBox(width: 46),
          ]),
          if (_teamMembers.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(color: _borderColor(context))),

          ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _teamMembers.length,
            separatorBuilder: (_,__) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: _borderColor(context))),
            itemBuilder: (ctx, i) {
              final m = _teamMembers[i];
              final storeData = m['stores'];
              final storeDisplay = storeData != null ? '${storeData['name']} (${storeData['city']})' : 'Global / Unassigned';

              return Row(children: [
                CircleAvatar(radius: 22, backgroundColor: AppColors.accent, child: Text(m['email'][0].toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['email'].split('@')[0], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))), const SizedBox(height: 2), Text(m['email'], style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context)))])),
                Expanded(flex: 2, child: Row(children: [_roleBadge(m['role'] ?? 'Manager')])),
                Expanded(flex: 2, child: Row(children: [ Icon(Icons.storefront, size: 16, color: _subtextColor(context)), const SizedBox(width: 6), Flexible(child: Text(storeDisplay, style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context), fontWeight: FontWeight.w600)))])),
                Container(
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                  child: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20), onPressed: () async {
                    await Supabase.instance.client.from('team_members').delete().eq('id', m['id']);
                    _loadTeamMembers();
                    _showToast('Member removed from whitelist.', AppColors.info);
                  }),
                )
              ]);
            },
          )
        ])
    );
  }

  // ─── STORES TAB ──────────────────────────────────────────────────────────────
  Widget _storesTab() {
    final available = _storesList.where((s) => (s['is_active'] ?? true) == true).toList();
    final unavailable = _storesList.where((s) => (s['is_active'] ?? true) == false).toList();

    return _sectionCard(
        title: 'Manage Stores & Hubs',
        subtitle: '${_storesList.length} total stores registered',
        icon: Icons.store_mall_directory_outlined,
        iconColor: Colors.deepPurpleAccent,
        actionWidget: ElevatedButton.icon(
          onPressed: () => _showAddOrEditStoreDialog(null),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text('Add Store', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2, shadowColor: AppColors.primary.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            _buildStoreListCard(
              title: 'Open / Available Stores',
              stores: available,
              isFlickering: true,
              themeColor: _isDark(context) ? Colors.greenAccent : Colors.green,
              bgColor: _isDark(context) ? Colors.greenAccent.withOpacity(0.08) : Colors.green.shade50,
            ),
            const SizedBox(height: 32),
            _buildStoreListCard(
              title: 'Closed / Unavailable Stores',
              stores: unavailable,
              isFlickering: false,
              themeColor: _isDark(context) ? Colors.redAccent : Colors.red,
              bgColor: _isDark(context) ? Colors.redAccent.withOpacity(0.08) : Colors.red.shade50,
            ),
          ],
        )
    );
  }

  Widget _buildStoreListCard({required String title, required List<Map<String, dynamic>> stores, required bool isFlickering, required Color themeColor, required Color bgColor}) {
    return Container(
      decoration: BoxDecoration(color: _bgColor(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor(context))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: isFlickering
                ? _FlickerText(text: title, style: GoogleFonts.outfit(fontSize: 16, color: themeColor, fontWeight: FontWeight.bold))
                : Text(title, style: GoogleFonts.outfit(fontSize: 16, color: themeColor, fontWeight: FontWeight.bold)),
          ),
          stores.isEmpty
              ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No $title found.', style: GoogleFonts.inter(color: _subtextColor(context)))))
              : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stores.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)),
              itemBuilder: (ctx, i) {
                final s = stores[i];
                final isActive = s['is_active'] ?? true;

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: s['logo_url'] != null && s['logo_url'].toString().isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(s['logo_url'], fit: BoxFit.cover, errorBuilder: (c, e, st) => const Icon(Icons.storefront_rounded, color: AppColors.primary)))
                          : const Icon(Icons.storefront_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor(context))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(child: Text('${s['address']}, ${s['city'] ?? ''}', style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ])),
                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Contact / Location', style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context))),
                      const SizedBox(height: 4),
                      Text(s['phone'] ?? 'N/A', style: GoogleFonts.inter(fontSize: 13, color: _textColor(context), fontWeight: FontWeight.w600)),
                      Text('Lat: ${s['latitude'] ?? '-'}, Lng: ${s['longitude'] ?? '-'}', style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context))),
                    ])),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => _toggleStoreStatus(s),
                          icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                          label: Text(isActive ? 'Close Store' : 'Open Store', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: isActive ? AppColors.warning : AppColors.success),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18), tooltip: 'Edit Store', onPressed: () => _showAddOrEditStoreDialog(s)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18), tooltip: 'Delete Store', onPressed: () async {
                            await Supabase.instance.client.from('stores').delete().eq('id', s['id']);
                            _loadStores();
                            _showToast('Store deleted.', AppColors.info);
                          }),
                        )
                      ],
                    )
                  ]),
                );
              }
          )
        ],
      ),
    );
  }

  void _showAddOrEditStoreDialog(Map<String, dynamic>? existingStore) {
    final isEditing = existingStore != null;

    final nameCtrl = TextEditingController(text: isEditing ? existingStore['name'] : '');
    final addressCtrl = TextEditingController(text: isEditing ? existingStore['address'] : '');
    final cityCtrl = TextEditingController(text: isEditing ? existingStore['city'] : '');
    final phoneCtrl = TextEditingController(text: isEditing ? existingStore['phone'] : '');
    final distanceCtrl = TextEditingController(text: isEditing && existingStore['distance_km'] != null ? existingStore['distance_km'].toString() : '');
    final latCtrl = TextEditingController(text: isEditing && existingStore['latitude'] != null ? existingStore['latitude'].toString() : '');
    final lngCtrl = TextEditingController(text: isEditing && existingStore['longitude'] != null ? existingStore['longitude'].toString() : '');

    Uint8List? selectedImageBytes;
    String? selectedImageExt;
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
            builder: (innerContext, setStateDialog) {
              return AlertDialog(
                backgroundColor: _surfaceColor(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))),
                title: Text(isEditing ? 'Edit Store' : 'Add New Store', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textColor(context))),
                content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Text('Store Logo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setStateDialog(() {
                                selectedImageBytes = bytes;
                                selectedImageExt = image.name.split('.').last;
                              });
                            }
                          },
                          child: Container(
                            height: 140, width: double.infinity,
                            decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor(context), style: BorderStyle.solid)),
                            child: selectedImageBytes != null
                                ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(selectedImageBytes!, fit: BoxFit.cover, width: double.infinity)),
                                Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Text('Change Logo', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                              ],
                            )
                                : (isEditing && existingStore['logo_url'] != null && existingStore['logo_url'].toString().isNotEmpty)
                                ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(existingStore['logo_url'], fit: BoxFit.cover, width: double.infinity)),
                                Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Text('Change Logo', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                              ],
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.primary)),
                                const SizedBox(height: 12),
                                Text('Click to select a logo', style: GoogleFonts.inter(color: _textColor(context), fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(children: [
                          Expanded(child: _textField('Store Name *', nameCtrl, hint: 'e.g. Dhanmondi Hub')),
                          const SizedBox(width: 16),
                          Expanded(child: _textField('City *', cityCtrl, hint: 'e.g. Dhaka')),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(flex: 2, child: _textField('Full Address *', addressCtrl, hint: 'Full street address')),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _textField('Phone Number', phoneCtrl, hint: '+880...')),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _textField('Distance / Coverage (km)', distanceCtrl, hint: 'e.g. 5.0')),
                          const SizedBox(width: 16),
                          Expanded(child: _textField('Latitude', latCtrl, hint: 'e.g. 23.8103')),
                          const SizedBox(width: 16),
                          Expanded(child: _textField('Longitude', lngCtrl, hint: 'e.g. 90.4125')),
                        ]),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context), fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
                        _showToast('Store Name and Address are required', AppColors.warning);
                        return;
                      }

                      setStateDialog(() => isSubmitting = true);

                      try {
                        String? finalImageUrl = isEditing ? existingStore['logo_url'] : null;

                        if (selectedImageBytes != null) {
                          final timestamp = DateTime.now().millisecondsSinceEpoch;
                          final filePath = 'store_$timestamp.$selectedImageExt';

                          await Supabase.instance.client.storage.from('store-images').uploadBinary(filePath, selectedImageBytes!);
                          finalImageUrl = Supabase.instance.client.storage.from('store-images').getPublicUrl(filePath);
                        }

                        final payload = {
                          'name': nameCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'city': cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : null,
                          'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                          'distance_km': double.tryParse(distanceCtrl.text.trim()),
                          'latitude': double.tryParse(latCtrl.text.trim()),
                          'longitude': double.tryParse(lngCtrl.text.trim()),
                          'logo_url': finalImageUrl,
                        };

                        if (isEditing) {
                          await Supabase.instance.client.from('stores').update(payload).eq('id', existingStore['id']);
                        } else {
                          await Supabase.instance.client.from('stores').insert(payload);
                        }

                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          _loadStores();
                          _showToast(isEditing ? 'Store updated successfully' : 'Store added successfully', AppColors.success);
                        }
                      } catch (e) {
                        _showToast('Error: $e', AppColors.error);
                        setStateDialog(() => isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEditing ? 'Update Store' : 'Save Store', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              );
            }
        )
    );
  }

  // ─── SERVICES TAB ────────────────────────────────────────────────────────────
  Widget _servicesTab() {
    final available = _servicesList.where((s) => (s['is_active'] ?? true) == true).toList();
    final unavailable = _servicesList.where((s) => (s['is_active'] ?? true) == false).toList();

    return _sectionCard(
        title: 'Manage Services',
        subtitle: '${_servicesList.length} total services across the platform',
        icon: Icons.dry_cleaning_outlined,
        iconColor: Colors.blueAccent,
        actionWidget: ElevatedButton.icon(
          onPressed: () => _showAddOrEditServiceDialog(null),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text('Add Service', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2, shadowColor: AppColors.primary.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            _buildServiceListCard(
              title: 'Available Services',
              services: available,
              isFlickering: true,
              themeColor: _isDark(context) ? Colors.greenAccent : Colors.green,
              bgColor: _isDark(context) ? Colors.greenAccent.withOpacity(0.08) : Colors.green.shade50,
            ),
            const SizedBox(height: 32),
            _buildServiceListCard(
              title: 'Unavailable Services',
              services: unavailable,
              isFlickering: false,
              themeColor: _isDark(context) ? Colors.redAccent : Colors.red,
              bgColor: _isDark(context) ? Colors.redAccent.withOpacity(0.08) : Colors.red.shade50,
            ),
          ],
        )
    );
  }

  Widget _buildServiceListCard({required String title, required List<Map<String, dynamic>> services, required bool isFlickering, required Color themeColor, required Color bgColor}) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: isFlickering
                ? _FlickerText(text: title, style: GoogleFonts.outfit(fontSize: 16, color: themeColor, fontWeight: FontWeight.bold))
                : Text(title, style: GoogleFonts.outfit(fontSize: 16, color: themeColor, fontWeight: FontWeight.bold)),
          ),
          services.isEmpty
              ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No $title found.', style: GoogleFonts.inter(color: _subtextColor(context)))))
              : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)),
              itemBuilder: (ctx, i) {
                final s = services[i];
                final isActive = s['is_active'] ?? true;

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: s['image_url'] != null && s['image_url'].toString().isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(s['image_url'], fit: BoxFit.cover, errorBuilder: (c, e, st) => const Icon(Icons.local_laundry_service, color: AppColors.primary)))
                          : const Icon(Icons.local_laundry_service, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(s['category'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: _subtextColor(context))),
                          const SizedBox(width: 8),
                          if (s['tags'] != null && (s['tags'] as List).isNotEmpty)
                            ...((s['tags'] as List).map((tag) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(tag.toString(), style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold))),
                            )))
                        ],
                      ),
                    ])),
                    Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Price', style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context))),
                      Text('৳${s['price']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                    ])),
                    Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Duration', style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context))),
                      Text(s['duration'] ?? 'N/A', style: GoogleFonts.inter(fontSize: 14, color: _textColor(context), fontWeight: FontWeight.w600)),
                    ])),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => _toggleServiceStatus(s),
                          icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                          label: Text(isActive ? 'Make Unavailable' : 'Make Available', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: isActive ? AppColors.warning : AppColors.success),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18), tooltip: 'Edit Service', onPressed: () => _showAddOrEditServiceDialog(s)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18), tooltip: 'Delete Service', onPressed: () async {
                            await Supabase.instance.client.from('services').delete().eq('id', s['id']);
                            _loadServices();
                            _showToast('Service deleted.', AppColors.info);
                          }),
                        )
                      ],
                    )
                  ]),
                );
              }
          )
        ],
      ),
    );
  }

  void _showAddOrEditServiceDialog(Map<String, dynamic>? existingService) {
    final isEditing = existingService != null;

    final titleCtrl = TextEditingController(text: isEditing ? existingService['title'] : '');
    final categoryCtrl = TextEditingController(text: isEditing ? existingService['category'] : 'Laundry');
    final descCtrl = TextEditingController(text: isEditing ? existingService['description'] : '');
    final priceCtrl = TextEditingController(text: isEditing ? existingService['price'].toString() : '');

    final tag1Ctrl = TextEditingController();
    final tag2Ctrl = TextEditingController();

    if (isEditing && existingService['tags'] != null && (existingService['tags'] as List).isNotEmpty) {
      final tags = existingService['tags'] as List;
      tag1Ctrl.text = tags[0].toString();
      if (tags.length > 1) tag2Ctrl.text = tags[1].toString();
    }

    String duration = isEditing && existingService['duration'] != null ? existingService['duration'] : '12-24 hours';

    Uint8List? selectedImageBytes;
    String? selectedImageExt;
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
            builder: (innerContext, setStateDialog) {
              return AlertDialog(
                backgroundColor: _surfaceColor(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))),
                title: Text(isEditing ? 'Edit Service' : 'Add New Service', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textColor(context))),
                content: SizedBox(
                  width: 550,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Text('Service Image', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setStateDialog(() {
                                selectedImageBytes = bytes;
                                selectedImageExt = image.name.split('.').last;
                              });
                            }
                          },
                          child: Container(
                            height: 140, width: double.infinity,
                            decoration: BoxDecoration(
                              color: _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor(context), style: BorderStyle.solid),
                            ),
                            child: selectedImageBytes != null
                                ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(selectedImageBytes!, fit: BoxFit.cover, width: double.infinity)),
                                Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Text('Change Image', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                              ],
                            )
                                : (isEditing && existingService['image_url'] != null && existingService['image_url'].toString().isNotEmpty)
                                ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(existingService['image_url'], fit: BoxFit.cover, width: double.infinity)),
                                Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Text('Change Image', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                              ],
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.primary)),
                                const SizedBox(height: 12),
                                Text('Click to select an image', style: GoogleFonts.inter(color: _textColor(context), fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(children: [
                          Expanded(child: _textField('Service Title *', titleCtrl, hint: 'e.g. Basic Wash')),
                          const SizedBox(width: 16),
                          Expanded(child: _textField('Category *', categoryCtrl, hint: 'e.g. Laundry')),
                        ]),
                        const SizedBox(height: 16),
                        _textField('Description', descCtrl, hint: 'Short description of the service'),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _textField('Price (৳) *', priceCtrl, hint: 'e.g. 150.00')),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Duration', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: duration,
                              items: ['12-24 hours', '24-48 hours', '48-78 hours'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(color: _textColor(context))))).toList(),
                              onChanged: (v) => setStateDialog(() => duration = v!),
                              decoration: _inputDeco(),
                              dropdownColor: _surfaceColor(context),
                            ),
                          ])),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _textField('Tag 1 (Optional)', tag1Ctrl, hint: 'e.g. Popular')),
                          const SizedBox(width: 16),
                          Expanded(child: _textField('Tag 2 (Optional)', tag2Ctrl, hint: 'e.g. Fast')),
                        ]),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context), fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      if (titleCtrl.text.isEmpty || priceCtrl.text.isEmpty || categoryCtrl.text.isEmpty) {
                        _showToast('Title, Category, and Price are required', AppColors.warning);
                        return;
                      }

                      setStateDialog(() => isSubmitting = true);

                      try {
                        String? finalImageUrl = isEditing ? existingService['image_url'] : null;

                        if (selectedImageBytes != null) {
                          final timestamp = DateTime.now().millisecondsSinceEpoch;
                          final filePath = 'service_$timestamp.$selectedImageExt';

                          await Supabase.instance.client.storage.from('service-images').uploadBinary(filePath, selectedImageBytes!);
                          finalImageUrl = Supabase.instance.client.storage.from('service-images').getPublicUrl(filePath);
                        }

                        final tags = [];
                        if (tag1Ctrl.text.isNotEmpty) tags.add(tag1Ctrl.text.trim());
                        if (tag2Ctrl.text.isNotEmpty) tags.add(tag2Ctrl.text.trim());

                        final payload = {
                          'title': titleCtrl.text.trim(),
                          'category': categoryCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                          'duration': duration,
                          'image_url': finalImageUrl,
                          'tags': tags,
                        };

                        if (isEditing) {
                          await Supabase.instance.client.from('services').update(payload).eq('id', existingService['id']);
                        } else {
                          await Supabase.instance.client.from('services').insert(payload);
                        }

                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          _loadServices();
                          _showToast(isEditing ? 'Service updated successfully' : 'Service added successfully', AppColors.success);
                        }
                      } catch (e) {
                        _showToast('Error: $e', AppColors.error);
                        setStateDialog(() => isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEditing ? 'Update Service' : 'Save Service', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              );
            }
        )
    );
  }

  // ─── BUSINESS TAB ────────────────────────────────────────────────────────────
  Widget _businessTab() {
    return _sectionCard(
        title: 'Business Settings',
        icon: Icons.business_center_outlined,
        iconColor: AppColors.warning,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _textField('Business Name', _bizNameCtrl)),
            const SizedBox(width: 24),
            Expanded(child: _textField('GST/Tax Number', _bizGstCtrl)),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _textField('Business Address', _bizAddrCtrl)),
            const SizedBox(width: 24),
            Expanded(child: _textField('Contact Number', _bizPhoneCtrl)),
          ]),
          const SizedBox(height: 32),
          _actionButton('Save Business Details', AppColors.primary, Icons.storefront_rounded, () async {
            setState(() => _isSaving = true);
            try {
              await Supabase.instance.client.from('settings').upsert({
                'id': 1, 'business_name': _bizNameCtrl.text.trim(), 'gst_number': _bizGstCtrl.text.trim(), 'business_address': _bizAddrCtrl.text.trim(), 'contact_number': _bizPhoneCtrl.text.trim(), 'updated_at': DateTime.now().toIso8601String()
              });
              _showToast('Business settings saved!', AppColors.success);
            } catch (e) {
              _showToast('Error saving business data: $e', AppColors.error);
            }
            setState(() => _isSaving = false);
          }),
        ])
    );
  }

  Widget _sectionCard({required String title, IconData? icon, Color? iconColor, String? subtitle, Widget? actionWidget, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: _borderColor(context), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (iconColor ?? AppColors.primary).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor ?? AppColors.primary, size: 24)), const SizedBox(width: 16)],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor(context))),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context)))],
          ]),
          const Spacer(),
          if (actionWidget != null) actionWidget,
        ]),
        const SizedBox(height: 32),
        child
      ]),
    );
  }

  Widget _textField(String label, TextEditingController ctrl, {String? hint, bool obscure = false, bool readOnly = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty) ...[Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))), const SizedBox(height: 8)],
      TextFormField(controller: ctrl, obscureText: obscure, readOnly: readOnly, style: GoogleFonts.inter(fontSize: 14, color: readOnly ? _subtextColor(context) : _textColor(context)), decoration: _inputDeco(hint: hint, readOnly: readOnly)),
    ]);
  }

  InputDecoration _inputDeco({String? hint, bool readOnly = false}) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.inter(color: _subtextColor(context).withOpacity(0.5), fontSize: 14),
    filled: true, fillColor: readOnly ? (_isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)) : _bgColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor(context))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor(context))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2.0)),
  );

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : onPressed,
      icon: _isSaving ? const SizedBox.shrink() : Icon(icon, color: Colors.white, size: 20),
      style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 2, shadowColor: color.withOpacity(0.5), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      label: _isSaving
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _roleBadge(String role) {
    final isSuper = role == 'Super Admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: (isSuper ? AppColors.primary : AppColors.success).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(role, style: GoogleFonts.inter(fontSize: 11, color: isSuper ? AppColors.primary : AppColors.success, fontWeight: FontWeight.bold)),
    );
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
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