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
  // UI State for dynamic expanding sections
  String? _expandedGroup; // 'admin', 'business', or null
  int? _tab; // null when no specific sub-tab is clicked yet

  bool _loading = false;
  bool _isSaving = false;
  bool _isInviting = false;

  // Controllers
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

  // Data Lists
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _storesList = [];
  List<Map<String, dynamic>> _servicesList = [];
  List<Map<String, dynamic>> _customersList = [];
  List<Map<String, dynamic>> _promosList = [];

  String _customerSearchQuery = '';
  String _promoSearchQuery = '';

  // Promo History State
  bool _showingPromoHistory = false;
  String _promoHistorySort = 'Newest';

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
      _emailCtrl.text = currentUser!.email ?? '';
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
      if (widget.isSuperAdmin) _loadPromos(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  // --- DATABASE OPERATIONS ---

  Future<void> _loadBusinessSettings() async {
    try {
      final data = await Supabase.instance.client.from('settings').select().eq('id', 1).maybeSingle();
      if (data != null) {
        _bizNameCtrl.text = data['business_name'] ?? '';
        _bizGstCtrl.text = data['gst_number'] ?? '';
        _bizAddrCtrl.text = data['business_address'] ?? '';
        _bizPhoneCtrl.text = data['contact_number'] ?? '';
      }
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _loadStores() async {
    try {
      final data = await Supabase.instance.client.from('stores').select().order('created_at', ascending: false);
      if (mounted) setState(() => _storesList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _loadTeamMembers() async {
    try {
      final data = await Supabase.instance.client.from('team_members').select('*, stores(name, city)').order('created_at');
      if (mounted) setState(() => _teamMembers = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _loadServices() async {
    try {
      final data = await Supabase.instance.client.from('services').select().order('created_at', ascending: false);
      if (mounted) setState(() => _servicesList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _loadCustomers() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select().order('created_at', ascending: false);
      if (mounted) setState(() => _customersList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _loadPromos() async {
    try {
      final data = await Supabase.instance.client.from('promos').select().order('created_at', ascending: false);
      if (mounted) setState(() => _promosList = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _toggleServiceStatus(Map<String, dynamic> service) async {
    final newStatus = !(service['is_active'] ?? true);
    try {
      await Supabase.instance.client.from('services').update({'is_active': newStatus}).eq('id', service['id']);
      _loadServices();
      _showToast(newStatus ? '${service['title']} is now Available' : '${service['title']} is now Unavailable', newStatus ? AppColors.success : AppColors.warning);
    } catch (e) { _showToast('Error updating status: $e', AppColors.error); }
  }

  Future<void> _toggleStoreStatus(Map<String, dynamic> store) async {
    final newStatus = !(store['is_active'] ?? true);
    try {
      await Supabase.instance.client.from('stores').update({'is_active': newStatus}).eq('id', store['id']);
      _loadStores();
      _showToast(newStatus ? '${store['name']} is now Open' : '${store['name']} is now Closed', newStatus ? AppColors.success : AppColors.warning);
    } catch (e) { _showToast('Error updating store status: $e', AppColors.error); }
  }

  Future<void> _togglePromoStatus(Map<String, dynamic> promo) async {
    final newStatus = !(promo['is_active'] ?? true);
    try {
      await Supabase.instance.client.from('promos').update({'is_active': newStatus}).eq('id', promo['id']);
      _loadPromos();
      _showToast(newStatus ? 'Promo activated' : 'Promo moved to history', newStatus ? AppColors.success : AppColors.warning);
    } catch (e) { _showToast('Error updating promo: $e', AppColors.error); }
  }

  // --- UI COMPONENTS ---

  Widget _buildCategoryCard(String title, IconData icon, String groupId, String subtitle) {
    final isExpanded = _expandedGroup == groupId;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_expandedGroup == groupId) {
              _expandedGroup = null; // Collapse
              _tab = null; // Hide page content
            } else {
              _expandedGroup = groupId; // Expand newly selected
              _tab = null; // Hide page content until a specific sub-tab is clicked
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isExpanded ? const Color(0xFF4F46E5).withOpacity(0.04) : _surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isExpanded ? const Color(0xFF4F46E5).withOpacity(0.6) : _borderColor(context),
                width: isExpanded ? 2 : 1
            ),
            boxShadow: isExpanded ? [] : [BoxShadow(color: Colors.black.withOpacity(_isDark(context)? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: isExpanded ? const Color(0xFF4F46E5) : (_isDark(context) ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle
                ),
                child: Icon(icon, color: isExpanded ? Colors.white : _subtextColor(context), size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: isExpanded ? const Color(0xFF4F46E5) : _textColor(context))),
                    const SizedBox(height: 6),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
                  ],
                ),
              ),
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isExpanded ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent, shape: BoxShape.circle),
                  child: Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: isExpanded ? const Color(0xFF4F46E5) : _subtextColor(context), size: 28)
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define all available tabs
    final List<Map<String, dynamic>> tabs = [
      {'id': 'profile', 'name': 'Profile', 'icon': Icons.person_outline},
      {'id': 'security', 'name': 'Security', 'icon': Icons.shield_outlined},
      if (widget.isSuperAdmin) {'id': 'team', 'name': 'Team', 'icon': Icons.people_outline},
      if (widget.isSuperAdmin) {'id': 'business', 'name': 'Business', 'icon': Icons.business_center_outlined},

      if (widget.isSuperAdmin) {'id': 'customers', 'name': 'Customers', 'icon': Icons.manage_accounts_outlined},
      if (widget.isSuperAdmin) {'id': 'promos', 'name': 'Promos', 'icon': Icons.campaign_outlined},
      if (widget.isSuperAdmin) {'id': 'stores', 'name': 'Stores', 'icon': Icons.store_mall_directory_outlined},
      if (widget.isSuperAdmin) {'id': 'services', 'name': 'Services', 'icon': Icons.dry_cleaning_outlined},
    ];

    if (_tab != null && _tab! >= tabs.length) _tab = null;

    // Define Groupings
    final adminTabIds = ['profile', 'security', 'team', 'business'];
    final bizTabIds = ['customers', 'promos', 'stores', 'services'];

    final adminTabs = tabs.where((t) => adminTabIds.contains(t['id'])).toList();
    final bizTabs = tabs.where((t) => bizTabIds.contains(t['id'])).toList();

    // Reusable builder for the animated sub-tabs row
    Widget buildTabRow(List<Map<String, dynamic>> tabGroup) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0).withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: tabGroup.map((t) {
                  final realIndex = tabs.indexOf(t);
                  final sel = _tab == realIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() { _tab = realIndex; _isInviting = false; });
                      if (t['id'] == 'team') _loadTeamMembers();
                      if (t['id'] == 'customers') _loadCustomers();
                      if (t['id'] == 'promos') _loadPromos();
                      if (t['id'] == 'stores') _loadStores();
                      if (t['id'] == 'services') _loadServices();
                      if (t['id'] == 'business') _loadBusinessSettings();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                          color: sel ? _surfaceColor(context) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(_isDark(context) ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 2))] : []
                      ),
                      child: Row(children: [
                        Icon(t['icon'] as IconData, size: 18, color: sel ? AppColors.primary : _subtextColor(context)),
                        const SizedBox(width: 8),
                        Text(t['name'] as String, style: GoogleFonts.inter(color: sel ? _textColor(context) : _subtextColor(context), fontWeight: sel ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
                      ]),
                    ),
                  );
                }).toList()
            ),
          ),
        ),
      );
    }

    return Container(
      color: _bgColor(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Static Top Header
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

        // Scrollable Body Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 1. MAIN CARDS SECTION
                  Row(
                      children: [
                        Expanded(
                            child: _buildCategoryCard('Administration Settings', Icons.admin_panel_settings_outlined, 'admin', 'Manage profile, security, team & core business details')
                        ),
                        if (widget.isSuperAdmin) const SizedBox(width: 24),
                        if (widget.isSuperAdmin) Expanded(
                            child: _buildCategoryCard('Business Settings', Icons.storefront_outlined, 'business', 'Manage customers, active promos, stores & laundry services')
                        ),
                      ]
                  ),

                  // 2. ANIMATED SUB-TABS ROW (Only appears when a card is clicked)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _expandedGroup != null
                        ? Column(
                        children: [
                          const SizedBox(height: 32),
                          buildTabRow(_expandedGroup == 'admin' ? adminTabs : bizTabs),
                        ]
                    )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),

                  // 3. ACTUAL TAB CONTENT (Beautifully animated when a specific sub-tab is clicked)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.05), // Subtle slide up from bottom
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _tab != null
                        ? Container(
                      key: ValueKey<int>(_tab!),
                      margin: const EdgeInsets.only(top: 32),
                      child: Builder(builder: (context) {
                        final id = tabs[_tab!]['id'];
                        if (id == 'profile') return _profileTab();
                        if (id == 'security') return _securityTab();
                        if (id == 'team') return _teamTab();
                        if (id == 'business') return _businessTab();
                        if (id == 'customers') return _customersTab();
                        if (id == 'promos') return _promosTab();
                        if (id == 'stores') return _storesTab();
                        if (id == 'services') return _servicesTab();
                        return const SizedBox.shrink();
                      }),
                    )
                        : const SizedBox.shrink(key: ValueKey<String>('empty_tab')),
                  ),
                ]
            ),
          ),
        ),
      ]),
    );
  }

  // --- TAB BUILDERS ---

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

  Widget _teamTab() {
    return _sectionCard(
        title: 'Team Members',
        subtitle: '${_teamMembers.length + 1} members with access',
        actionWidget: ElevatedButton.icon(
          onPressed: () => setState(() => _isInviting = !_isInviting),
          icon: Icon(_isInviting ? Icons.close : Icons.person_add_outlined, color: Colors.white, size: 18),
          label: Text(_isInviting ? 'Cancel' : 'Invite Member', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                        _showToast('Member added to whitelist!', AppColors.success);
                      } catch(e) {
                        _showToast('Error adding member: $e', AppColors.error);
                      }
                      setState(() => _isSaving = false);
                    })),
                  ]),
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
                  }),
                )
              ]);
            },
          )
        ])
    );
  }

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
          decoration: _inputDeco(hint: 'Search by name or phone...').copyWith(prefixIcon: Icon(Icons.search_rounded, color: _subtextColor(context), size: 18)),
        ),
      ),
      child: filteredCustomers.isEmpty
          ? Center(child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Text('No customers found.', style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 15)),
      ))
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredCustomers.length,
        separatorBuilder: (_, __) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: _borderColor(context))),
        itemBuilder: (ctx, i) {
          final c = filteredCustomers[i];
          final name = c['full_name'] ?? 'Unknown User';
          final phone = c['phone'] ?? 'No phone';

          return Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))), const SizedBox(height: 2), Text(phone, style: GoogleFonts.inter(fontSize: 13, color: _subtextColor(context)))])),
              OutlinedButton.icon(
                onPressed: () => _showCustomerOrderHistory(c),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: Text('View Orders', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCustomerOrderHistory(Map<String, dynamic> customer) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order History: ${customer['full_name']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textColor(context))),
            IconButton(icon: Icon(Icons.close, color: _subtextColor(context)), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(width: 500, height: 400, child: FutureBuilder(future: Supabase.instance.client.from('orders').select().eq('user_id', customer['id']).order('created_at', ascending: false), builder: (c, AsyncSnapshot<List<dynamic>> snap) {
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          if(snap.data!.isEmpty) return Center(child: Text('No orders found for this user.', style: GoogleFonts.inter(color: _subtextColor(context))));
          return ListView.separated(
              itemCount: snap.data!.length,
              separatorBuilder: (_, __) => Divider(color: _borderColor(context)),
              itemBuilder: (c, i) {
                final o = snap.data![i];
                return ListTile(
                    title: Text('#${o['order_number']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textColor(context))),
                    subtitle: Text(o['created_at'].toString().split('T')[0], style: GoogleFonts.inter(color: _subtextColor(context))),
                    trailing: Text('৳${o['total_price']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary))
                );
              }
          );
        }))
    ));
  }

  // --- PROMOS TAB (ACTIVE vs HISTORY & EDITABLE) ---

  Widget _promosTab() {
    final now = DateTime.now();
    List<Map<String, dynamic>> activePromos = [];
    List<Map<String, dynamic>> historyPromos = [];

    // Separate Promos into Active and History
    for (var p in _promosList) {
      bool manuallyInactive = (p['is_active'] == false);
      bool isExpired = p['valid_until'] != null && now.isAfter(DateTime.parse(p['valid_until']).toLocal());
      bool isFullyUsed = p['usage_limit'] != null && (p['times_used'] ?? 0) >= p['usage_limit'];

      bool isHistory = manuallyInactive || isExpired || isFullyUsed;

      // Apply search filter
      if (_promoSearchQuery.isNotEmpty) {
        final q = _promoSearchQuery.toLowerCase();
        final code = (p['code'] ?? '').toString().toLowerCase();
        final title = (p['title'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !title.contains(q) && !desc.contains(q)) {
          continue;
        }
      }

      if (isHistory) {
        String reason = 'Manually Disabled';
        if (isFullyUsed) reason = 'Limit Reached';
        if (isExpired) reason = 'Expired';
        p['_history_reason'] = reason;
        historyPromos.add(p);
      } else {
        activePromos.add(p);
      }
    }

    // Sort History
    if (_promoHistorySort == 'Oldest') {
      historyPromos.sort((a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''));
    } else {
      historyPromos.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    }

    final displayList = _showingPromoHistory ? historyPromos : activePromos;

    return _sectionCard(
      title: 'Promotions & Offers',
      subtitle: 'Create dynamic offers, manage limits, and view past campaigns.',
      icon: Icons.campaign_outlined,
      iconColor: const Color(0xFF8B5CF6),
      actionWidget: ElevatedButton.icon(
        onPressed: () => _showAddPromoDialog(null),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
        label: Text('Create Promo', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Tabs Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (v) => setState(() => _promoSearchQuery = v),
                  style: GoogleFonts.inter(fontSize: 14, color: _textColor(context)),
                  decoration: _inputDeco(hint: 'Search title, code or description...').copyWith(prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                ),
              ),
              const SizedBox(width: 24),

              // Custom Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor(context))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _customTab('Active (${activePromos.length})', !_showingPromoHistory, () => setState(() => _showingPromoHistory = false)),
                    _customTab('History (${historyPromos.length})', _showingPromoHistory, () => setState(() => _showingPromoHistory = true)),
                  ],
                ),
              ),

              // Sorting (Only visible in History)
              if (_showingPromoHistory) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: _bgColor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor(context))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _promoHistorySort,
                      icon: Icon(Icons.sort, color: _subtextColor(context), size: 18),
                      style: GoogleFonts.inter(color: _textColor(context), fontSize: 13, fontWeight: FontWeight.w600),
                      dropdownColor: _surfaceColor(context),
                      items: ['Newest', 'Oldest'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _promoHistorySort = v!),
                    ),
                  ),
                )
              ]
            ],
          ),
          const SizedBox(height: 24),

          displayList.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(_showingPromoHistory ? 'No past campaigns found in history.' : 'No active promotional codes found.', style: GoogleFonts.inter(color: _subtextColor(context))),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final p = displayList[i];

              // Style based on active/history status
              final isHistoryMode = _showingPromoHistory;
              final Color accentColor = isHistoryMode ? _subtextColor(context) : const Color(0xFF8B5CF6);
              final Color boxBg = isHistoryMode ? (_isDark(context) ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.grey.shade50) : _bgColor(context);
              final Color iconBg = isHistoryMode ? Colors.grey.withOpacity(0.1) : const Color(0xFF8B5CF6).withOpacity(0.1);

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isHistoryMode ? _borderColor(context) : const Color(0xFF8B5CF6).withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    // Banner Thumbnail or Default Icon
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isHistoryMode ? Colors.grey.shade400 : const Color(0xFF8B5CF6))),
                      child: p['banner_url'] != null && p['banner_url'].toString().isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: ColorFiltered(
                          colorFilter: isHistoryMode ? const ColorFilter.matrix([0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0.2126,0.7152,0.0722,0,0, 0,0,0,1,0]) : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: Image.network(p['banner_url'], fit: BoxFit.cover)
                      ))
                          : Center(child: Text(p['code'].toString().substring(0, 3).toUpperCase(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, color: accentColor))),
                    ),
                    const SizedBox(width: 24),

                    // Details
                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['title'] ?? 'Flash Sale', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: isHistoryMode ? _subtextColor(context) : _textColor(context))),
                      const SizedBox(height: 4),
                      Text(p['code'].toString().toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: accentColor)),
                      const SizedBox(height: 4),
                      Text(p['description'] ?? 'No description', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(p['discount_type'] == 'percentage' ? '${p['discount_value']}% OFF' : '৳${p['discount_value']} OFF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isHistoryMode ? _subtextColor(context) : AppColors.success)),
                          const SizedBox(width: 16),
                          Text('Used: ${p['times_used'] ?? 0} / ${p['usage_limit'] ?? '∞'}', style: GoogleFonts.inter(fontSize: 12, color: _subtextColor(context))),
                        ],
                      )
                    ])),

                    // Actions / Status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isHistoryMode) ...[
                          // Display Reason in History Mode (No Switch, No Edit)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(p['_history_reason'] ?? 'Archived', style: GoogleFonts.inter(fontSize: 11, color: _subtextColor(context), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 16),
                        ] else ...[
                          // Active Controls
                          Switch.adaptive(value: true, activeColor: AppColors.success, onChanged: (_) => _togglePromoStatus(p)),
                          IconButton(icon: const Icon(Icons.edit, color: Color(0xFF8B5CF6)), tooltip: 'Edit', onPressed: () => _showAddPromoDialog(p)),
                        ],
                        // Delete is available in both
                        IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), tooltip: 'Delete', onPressed: () async {
                          await Supabase.instance.client.from('promos').delete().eq('id', p['id']);
                          _loadPromos();
                        }),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddPromoDialog(Map<String, dynamic>? existingPromo) {
    final isEditing = existingPromo != null;

    final titleCtrl = TextEditingController(text: isEditing ? existingPromo['title'] : '');
    final codeCtrl = TextEditingController(text: isEditing ? existingPromo['code'] : '');
    final descCtrl = TextEditingController(text: isEditing ? existingPromo['description'] : '');
    final discountValCtrl = TextEditingController(text: isEditing ? existingPromo['discount_value']?.toString() : '');
    final maxDiscountCtrl = TextEditingController(text: isEditing && existingPromo['max_discount_amount'] != null ? existingPromo['max_discount_amount'].toString() : '');
    final minOrderCtrl = TextEditingController(text: isEditing && existingPromo['min_order_amount'] != null ? existingPromo['min_order_amount'].toString() : '');

    final usageLimitCtrl = TextEditingController(text: isEditing && existingPromo['usage_limit'] != null ? existingPromo['usage_limit'].toString() : '');

    String discountType = isEditing ? (existingPromo['discount_type'] ?? 'percentage') : 'percentage';
    String? selectedServiceId = isEditing && existingPromo['target_service_id'] != null ? existingPromo['target_service_id'].toString() : null;
    DateTime? selectedDate = isEditing && existingPromo['valid_until'] != null ? DateTime.tryParse(existingPromo['valid_until'])?.toLocal() : null;

    bool isSubmitting = false;

    Uint8List? selectedImageBytes;
    String? selectedImageExt;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerContext, setStateDialog) {
          return AlertDialog(
            backgroundColor: _surfaceColor(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))),
            title: Text(isEditing ? 'Edit Campaign' : 'Launch Campaign', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textColor(context))),
            content: SizedBox(width: 600, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Image Picker
              Text('Promo Banner Image', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
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
                      Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Text('Change Banner', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                    ],
                  ) : (isEditing && existingPromo['banner_url'] != null && existingPromo['banner_url'].toString().isNotEmpty)
                      ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(existingPromo['banner_url'], fit: BoxFit.cover, width: double.infinity)),
                      Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)), child: Text('Change Banner', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))
                    ],
                  ) : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Color(0xFF8B5CF6))),
                      const SizedBox(height: 12),
                      Text('Click to upload promo banner', style: GoogleFonts.inter(color: _textColor(context), fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _textField('Campaign Title (e.g. Rainy Offer) *', titleCtrl, hint: 'Notification headline'),
              const SizedBox(height: 16),

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Target Service', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(value: selectedServiceId, items: [const DropdownMenuItem(value: null, child: Text('All Services (Global Offer)')), ..._servicesList.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['title'] ?? '')))], onChanged: (v) => setStateDialog(() => selectedServiceId = v), decoration: _inputDeco(), dropdownColor: _surfaceColor(context)),
              ]),
              const SizedBox(height: 16),

              Row(children: [Expanded(child: _textField('Promo Code *', codeCtrl, hint: 'e.g. RAIN40')), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Type', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))), const SizedBox(height: 8), DropdownButtonFormField<String>(value: discountType, items: const [DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')), DropdownMenuItem(value: 'fixed', child: Text('Fixed (৳)'))], onChanged: (v) => setStateDialog(() => discountType = v!), decoration: _inputDeco(), dropdownColor: _surfaceColor(context))]))]),
              const SizedBox(height: 16),
              _textField('Detailed Description *', descCtrl, hint: 'Details for user'),
              const SizedBox(height: 16),

              // Value and Max Disc Row
              Row(children: [Expanded(child: _textField('Value *', discountValCtrl, hint: 'e.g. 40')), const SizedBox(width: 16), Expanded(child: _textField('Max Disc (৳)', maxDiscountCtrl, hint: 'Cap limit'))]),
              const SizedBox(height: 16),

              // Min Order and Usage Limit Row
              Row(children: [Expanded(child: _textField('Min Order (৳)', minOrderCtrl, hint: 'e.g. 50')), const SizedBox(width: 16), Expanded(child: _textField('Total Usage Limit', usageLimitCtrl, hint: 'e.g. 10 (Optional)'))]),
              const SizedBox(height: 16),

              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Expiry Date', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))), const SizedBox(height: 8), InkWell(onTap: () async { final p = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2030)); if (p != null) setStateDialog(() => selectedDate = p); }, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _bgColor(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor(context))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(selectedDate == null ? 'No Expiry' : '${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}', style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))), Icon(Icons.calendar_today, size: 16, color: _subtextColor(context))])))]),
              const SizedBox(height: 24),

              // Informative container explaining that DB handles notifications
              if (!isEditing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFF8B5CF6), size: 20),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Push notifications are automatically triggered by your database when a new promo is launched.', style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: _textColor(context)))),
                    ],
                  ),
                ),
            ]))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context)))),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (titleCtrl.text.isEmpty || codeCtrl.text.isEmpty || discountValCtrl.text.isEmpty) {
                    _showToast('Fill required fields', AppColors.warning);
                    return;
                  }

                  setStateDialog(() => isSubmitting = true);

                  try {
                    String? finalImageUrl = isEditing ? existingPromo['banner_url'] : null;

                    if (selectedImageBytes != null) {
                      final timestamp = DateTime.now().millisecondsSinceEpoch;
                      final filePath = 'promo_$timestamp.$selectedImageExt';
                      await Supabase.instance.client.storage.from('promo_banner').uploadBinary(filePath, selectedImageBytes!);
                      finalImageUrl = Supabase.instance.client.storage.from('promo_banner').getPublicUrl(filePath);
                    }

                    final payload = {
                      'title': titleCtrl.text.trim(), // Title goes into the database here
                      'code': codeCtrl.text.trim().toUpperCase(),
                      'description': descCtrl.text.trim(),
                      'discount_type': discountType,
                      'discount_value': double.parse(discountValCtrl.text.trim()),
                      'max_discount_amount': double.tryParse(maxDiscountCtrl.text.trim()),
                      'min_order_amount': double.tryParse(minOrderCtrl.text.trim()) ?? 0,
                      'usage_limit': int.tryParse(usageLimitCtrl.text.trim()),
                      'valid_until': selectedDate?.toIso8601String(),
                      'target_service_id': selectedServiceId,
                      'banner_url': finalImageUrl,
                      'is_active': true,
                    };

                    if (isEditing) {
                      await Supabase.instance.client.from('promos').update(payload).eq('id', existingPromo['id']);
                    } else {
                      await Supabase.instance.client.from('promos').insert(payload);
                    }

                    if (mounted) {
                      Navigator.pop(dialogCtx);
                      _loadPromos();
                      _showToast(isEditing ? 'Promo Updated!' : 'Promo Launched!', AppColors.success);
                    }
                  } catch (e) { _showToast('Database Error: $e', AppColors.error); setStateDialog(() => isSubmitting = false); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isEditing ? 'Update Promo' : 'Launch Promo', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  // --- STORES TAB ---
  Widget _storesTab() {
    final available = _storesList.where((s) => (s['is_active'] ?? true)).toList();
    final unavailable = _storesList.where((s) => !(s['is_active'] ?? true)).toList();
    return _sectionCard(title: 'Manage Stores', subtitle: '${_storesList.length} total hubs', actionWidget: ElevatedButton.icon(onPressed: () => _showAddOrEditStoreDialog(null), icon: const Icon(Icons.add, color: Colors.white, size: 18), label: Text('Add Store', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), child: Column(children: [_buildStoreListCard(title: 'Available Stores', stores: available, isFlickering: true, themeColor: Colors.green, bgColor: Colors.green.withOpacity(0.05)), const SizedBox(height: 32), _buildStoreListCard(title: 'Unavailable Stores', stores: unavailable, isFlickering: false, themeColor: Colors.red, bgColor: Colors.red.withOpacity(0.05))]));
  }

  Widget _buildStoreListCard({required String title, required List<Map<String, dynamic>> stores, required bool isFlickering, required Color themeColor, required Color bgColor}) {
    return Container(decoration: BoxDecoration(color: _bgColor(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: _borderColor(context))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))), child: isFlickering ? _FlickerText(text: title, style: GoogleFonts.outfit(color: themeColor, fontWeight: FontWeight.bold)) : Text(title, style: GoogleFonts.outfit(color: themeColor, fontWeight: FontWeight.bold))), ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: stores.length, separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)), itemBuilder: (ctx, i) { final s = stores[i]; final isActive = s['is_active'] ?? true; return ListTile(leading: CircleAvatar(backgroundImage: s['logo_url'] != null ? NetworkImage(s['logo_url']) : null, child: s['logo_url'] == null ? const Icon(Icons.storefront) : null), title: Text(s['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textColor(context))), subtitle: Text(s['address'] ?? '', style: GoogleFonts.inter(color: _subtextColor(context))), trailing: Row(mainAxisSize: MainAxisSize.min, children: [TextButton(onPressed: () => _toggleStoreStatus(s), child: Text(isActive ? 'Make Unavailable' : 'Make Available', style: GoogleFonts.inter(color: isActive ? Colors.orange : Colors.green, fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _showAddOrEditStoreDialog(s))])); })]));
  }

  void _showAddOrEditStoreDialog(Map<String, dynamic>? store) {
    final isEdit = store != null;
    final nameCtrl = TextEditingController(text: isEdit ? store['name'] : '');
    final addrCtrl = TextEditingController(text: isEdit ? store['address'] : '');
    final cityCtrl = TextEditingController(text: isEdit ? store['city'] : '');
    final phoneCtrl = TextEditingController(text: isEdit ? store['phone'] : '');
    final distCtrl = TextEditingController(text: isEdit && store['distance_km'] != null ? store['distance_km'].toString() : '');
    final latCtrl = TextEditingController(text: isEdit && store['latitude'] != null ? store['latitude'].toString() : '');
    final lngCtrl = TextEditingController(text: isEdit && store['longitude'] != null ? store['longitude'].toString() : '');

    Uint8List? imgBytes; String? ext; bool sub = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (c, setD) {
      return AlertDialog(backgroundColor: _surfaceColor(context), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _borderColor(context))), title: Text(isEdit ? 'Edit Store' : 'New Store', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textColor(context))), content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: () async { final ImagePicker p = ImagePicker(); final XFile? i = await p.pickImage(source: ImageSource.gallery); if (i != null) { final b = await i.readAsBytes(); setD(() { imgBytes = b; ext = i.name.split('.').last; }); } }, child: Center(child: CircleAvatar(radius: 50, backgroundColor: _bgColor(context), backgroundImage: imgBytes != null ? MemoryImage(imgBytes!) : (isEdit && store['logo_url']!=null ? NetworkImage(store['logo_url']) : null) as ImageProvider?, child: imgBytes == null && (!isEdit || store['logo_url'] == null) ? const Icon(Icons.camera_alt, size: 30) : null))),
        const SizedBox(height: 24),
        _textField('Store Name *', nameCtrl),
        const SizedBox(height: 12),
        _textField('Store Full Address *', addrCtrl),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _textField('City', cityCtrl)), const SizedBox(width: 12), Expanded(child: _textField('Contact Number', phoneCtrl))]),
        const SizedBox(height: 12),
        _textField('Range (km)', distCtrl),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _textField('Latitude', latCtrl)), const SizedBox(width: 12), Expanded(child: _textField('Longitude', lngCtrl))]),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context)))), ElevatedButton(onPressed: sub ? null : () async { setD(()=>sub=true); try { String? url = isEdit?store['logo_url']:null; if(imgBytes!=null){ final p = 'store_${DateTime.now().millisecondsSinceEpoch}.$ext'; await Supabase.instance.client.storage.from('store-images').uploadBinary(p, imgBytes!); url = Supabase.instance.client.storage.from('store-images').getPublicUrl(p); } final d = {'name':nameCtrl.text, 'address':addrCtrl.text, 'city':cityCtrl.text, 'phone':phoneCtrl.text, 'distance_km': double.tryParse(distCtrl.text), 'latitude': double.tryParse(latCtrl.text), 'longitude': double.tryParse(lngCtrl.text), 'logo_url':url}; if(isEdit) await Supabase.instance.client.from('stores').update(d).eq('id', store['id']); else await Supabase.instance.client.from('stores').insert(d); Navigator.pop(ctx); _loadStores(); } catch(e){_showToast('$e', Colors.red); setD(()=>sub=false);} }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(isEdit?'Update':'Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)))]);
    }));
  }

  // --- SERVICES TAB ---

  Widget _servicesTab() {
    final available = _servicesList.where((s) => (s['is_active'] ?? true)).toList();
    final unavailable = _servicesList.where((s) => !(s['is_active'] ?? true)).toList();
    return _sectionCard(
        title: 'Manage Services',
        subtitle: '${_servicesList.length} total services across the platform',
        icon: Icons.dry_cleaning_outlined,
        iconColor: const Color(0xFF3B82F6),
        actionWidget: ElevatedButton.icon(
          onPressed: () => _showAddOrEditServiceDialog(null),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text('Add Service', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
        ),
        child: Column(
            children: [
              _buildServiceListCard(
                title: 'Available Services',
                services: available,
                themeColor: const Color(0xFF22C55E),
                bgColor: const Color(0xFFDCFCE7),
              ),
              const SizedBox(height: 32),
              _buildServiceListCard(
                title: 'Unavailable Services',
                services: unavailable,
                themeColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEE2E2),
              )
            ]
        )
    );
  }

  Widget _buildServiceListCard({required String title, required List<Map<String, dynamic>> services, required Color themeColor, required Color bgColor}) {
    if (services.isEmpty) return const SizedBox.shrink();

    return Container(
        decoration: BoxDecoration(
            color: _bgColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor(context))
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _isDark(context) ? themeColor.withOpacity(0.1) : bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
                  child: Text(title, style: GoogleFonts.inter(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14))
              ),
              ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor(context)),
                  itemBuilder: (ctx, i) {
                    final s = services[i];
                    final isActive = s['is_active'] ?? true;
                    final List<dynamic> tags = s['tags'] ?? [];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Row(
                        children: [
                          // Image
                          Container(
                            height: 60, width: 60,
                            decoration: BoxDecoration(
                              color: _borderColor(context),
                              borderRadius: BorderRadius.circular(8),
                              image: s['image_url'] != null ? DecorationImage(image: NetworkImage(s['image_url']), fit: BoxFit.cover) : null,
                            ),
                            child: s['image_url'] == null ? const Center(child: Icon(Icons.local_laundry_service, color: Colors.grey)) : null,
                          ),
                          const SizedBox(width: 16),

                          // Title, Category and Tags
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor(context))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(s['category'] ?? '', style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 12)),
                                    if (tags.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      ...tags.where((t) => t.toString().isNotEmpty).map((t) => _buildServiceTag(t.toString())),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Price
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Price', style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('৳${s['price']?.toStringAsFixed(1) ?? '0.0'}', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ),

                          // Duration
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Duration', style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(s['duration'] ?? '12-24 hours', style: GoogleFonts.inter(color: _textColor(context), fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),

                          // Actions
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                  onPressed: () => _toggleServiceStatus(s),
                                  icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981), size: 18),
                                  label: Text(isActive ? 'Make Unavailable' : 'Make Available', style: GoogleFonts.inter(color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12))
                              ),
                              const SizedBox(width: 16),
                              // Edit Button
                              InkWell(
                                onTap: () => _showAddOrEditServiceDialog(s),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, size: 16, color: Color(0xFF4F46E5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Delete Button
                              InkWell(
                                onTap: () async {
                                  await Supabase.instance.client.from('services').delete().eq('id', s['id']);
                                  _loadServices();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }
              )
            ]
        )
    );
  }

  Widget _buildServiceTag(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
    );
  }

  void _showAddOrEditServiceDialog(Map<String, dynamic>? service) {
    final isEdit = service != null;
    final titleCtrl = TextEditingController(text: isEdit ? service['title'] : '');
    final catCtrl = TextEditingController(text: isEdit ? service['category'] : '');
    final priceCtrl = TextEditingController(text: isEdit ? service['price'].toString() : '');
    final descCtrl = TextEditingController(text: isEdit ? service['description'] : '');
    final tag1Ctrl = TextEditingController(text: (isEdit && service['tags'] != null && (service['tags'] as List).isNotEmpty) ? service['tags'][0] : '');
    final tag2Ctrl = TextEditingController(text: (isEdit && service['tags'] != null && (service['tags'] as List).length > 1) ? service['tags'][1] : '');

    // Safely construct dynamic duration options to avoid Flutter assertion errors
    List<String> durationOptions = ['12-24 hours', '24-48 hours', '48-72 hours'];
    String duration = isEdit ? (service['duration']?.toString() ?? '12-24 hours') : '12-24 hours';
    if (!durationOptions.contains(duration)) {
      durationOptions.add(duration);
    }

    Uint8List? imgBytes; String? ext; bool sub = false;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, setD) {
              return AlertDialog(
                  backgroundColor: _surfaceColor(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _borderColor(context))),
                  title: Text(isEdit ? 'Edit Service' : 'Add New Service', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: _textColor(context))),
                  content: SizedBox(
                      width: 600,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Service Image', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                                const SizedBox(height: 8),
                                GestureDetector(
                                    onTap: () async {
                                      final i = await ImagePicker().pickImage(source: ImageSource.gallery);
                                      if(i!=null){ final b = await i.readAsBytes(); setD((){imgBytes=b; ext=i.name.split('.').last;}); }
                                    },
                                    child: Container(
                                        height: 140,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                            color: _isDark(context) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _borderColor(context), style: BorderStyle.solid)
                                        ),
                                        child: imgBytes != null
                                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(imgBytes!, fit: BoxFit.cover))
                                            : (isEdit && service['image_url'] != null)
                                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(service['image_url'], fit: BoxFit.cover))
                                            : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), shape: BoxShape.circle),
                                                child: const Icon(Icons.cloud_upload_outlined, size: 24, color: Color(0xFF4F46E5))
                                            ),
                                            const SizedBox(height: 12),
                                            Text('Click to select an image', style: GoogleFonts.inter(color: _textColor(context), fontSize: 14, fontWeight: FontWeight.w500)),
                                          ],
                                        )
                                    )
                                ),
                                const SizedBox(height: 24),

                                Row(children: [
                                  Expanded(child: _textField('Service Title *', titleCtrl, hint: 'e.g. Basic Wash')),
                                  const SizedBox(width: 16),
                                  Expanded(child: _textField('Category *', catCtrl, hint: 'Laundry'))
                                ]),
                                const SizedBox(height: 16),

                                _textField('Description', descCtrl, hint: 'Short description of the service'),
                                const SizedBox(height: 16),

                                Row(children: [
                                  Expanded(child: _textField('Price (৳) *', priceCtrl, hint: 'e.g. 150.00')),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Duration', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))),
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: duration,
                                              decoration: _inputDeco(),
                                              dropdownColor: _surfaceColor(context),
                                              items: durationOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))))).toList(),
                                              onChanged: (v) => setD(() => duration = v!),
                                            ),
                                          ]
                                      )
                                  )
                                ]),
                                const SizedBox(height: 16),

                                Row(children: [
                                  Expanded(child: _textField('Tag 1 (Optional)', tag1Ctrl, hint: 'e.g. Popular')),
                                  const SizedBox(width: 16),
                                  Expanded(child: _textField('Tag 2 (Optional)', tag2Ctrl, hint: 'e.g. Fast'))
                                ]),
                              ]
                          )
                      )
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.inter(color: _subtextColor(context), fontWeight: FontWeight.w600))
                    ),
                    ElevatedButton(
                        onPressed: sub ? null : () async {
                          setD(()=>sub=true);
                          try {
                            String? url = isEdit ? service['image_url'] : null;
                            if(imgBytes!=null){
                              final p = 'service_${DateTime.now().millisecondsSinceEpoch}.$ext';
                              await Supabase.instance.client.storage.from('service-images').uploadBinary(p, imgBytes!);
                              url = Supabase.instance.client.storage.from('service-images').getPublicUrl(p);
                            }
                            final tags = [if(tag1Ctrl.text.isNotEmpty) tag1Ctrl.text, if(tag2Ctrl.text.isNotEmpty) tag2Ctrl.text];
                            final data = {
                              'title':titleCtrl.text,
                              'category': catCtrl.text,
                              'price':double.parse(priceCtrl.text),
                              'description':descCtrl.text,
                              'duration': duration,
                              'tags': tags,
                              'image_url':url
                            };
                            if(isEdit) {
                              await Supabase.instance.client.from('services').update(data).eq('id', service['id']);
                            } else {
                              await Supabase.instance.client.from('services').insert(data);
                            }
                            Navigator.pop(ctx);
                            _loadServices();
                          } catch(e) {
                            _showToast('$e', Colors.red);
                            setD(()=>sub=false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                        ),
                        child: Text(isEdit?'Update Service':'Save Service', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))
                    )
                  ]
              );
            }
        )
    );
  }

  // --- BUSINESS TAB ---
  Widget _businessTab() {
    return _sectionCard(title: 'Business Details', icon: Icons.business, child: Column(children: [
      Row(children: [Expanded(child: _textField('Business Name', _bizNameCtrl)), const SizedBox(width: 24), Expanded(child: _textField('Tax Number', _bizGstCtrl))]),
      const SizedBox(height: 24),
      Row(children: [Expanded(child: _textField('Business Address', _bizAddrCtrl)), const SizedBox(width: 24), Expanded(child: _textField('Contact Number', _bizPhoneCtrl))]),
      const SizedBox(height: 32),
      _actionButton('Save Business Settings', AppColors.primary, Icons.save, () async { try { await Supabase.instance.client.from('settings').upsert({'id': 1, 'business_name': _bizNameCtrl.text, 'gst_number': _bizGstCtrl.text, 'business_address': _bizAddrCtrl.text, 'contact_number': _bizPhoneCtrl.text}); _showToast('Settings Saved', AppColors.success); } catch (e) { _showToast('Error: $e', AppColors.error); } })
    ]));
  }

  // --- HELPERS ---

  Widget _customTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _surfaceColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Text(label, style: GoogleFonts.inter(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13, color: isSelected ? _textColor(context) : _subtextColor(context))),
      ),
    );
  }

  Widget _sectionCard({required String title, IconData? icon, Color? iconColor, String? subtitle, Widget? actionWidget, required Widget child}) => Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: _surfaceColor(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: _borderColor(context), width: 1.5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [if(icon!=null) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (iconColor ?? AppColors.primary).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor ?? AppColors.primary, size: 24)), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor(context))), if(subtitle!=null) Text(subtitle, style: GoogleFonts.inter(color: _subtextColor(context), fontSize: 14))]), const Spacer(), if(actionWidget!=null) actionWidget]), const SizedBox(height: 32), child]));

  Widget _textField(String label, TextEditingController ctrl, {bool obscure = false, bool readOnly = false, String? hint}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor(context))), const SizedBox(height: 8), TextFormField(controller: ctrl, obscureText: obscure, readOnly: readOnly, style: GoogleFonts.inter(fontSize: 14, color: _textColor(context)), decoration: _inputDeco(hint: hint))]);

  InputDecoration _inputDeco({String? hint}) => InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: _subtextColor(context).withOpacity(0.5)), filled: true, fillColor: _bgColor(context), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor(context))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _borderColor(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)));

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onTap) => ElevatedButton.icon(onPressed: _isSaving ? null : onTap, icon: Icon(icon, size: 18, color: Colors.white), label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  Widget _roleBadge(String role) => Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(role, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)));

  void _showToast(String msg, Color color) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.inter(color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }
}

class _FlickerText extends StatefulWidget {
  final String text; final TextStyle style;
  const _FlickerText({required this.text, required this.style});
  @override State<_FlickerText> createState() => _FlickerTextState();
}

class _FlickerTextState extends State<_FlickerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return FadeTransition(opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller), child: Text(widget.text, style: widget.style)); }
}