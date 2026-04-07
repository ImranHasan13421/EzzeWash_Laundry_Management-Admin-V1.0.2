// lib/features/home/admin_settings.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      if (widget.isSuperAdmin) _loadTeamMembers(),
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
    } catch (e) {
      debugPrint('Error loading business settings: $e');
    }
  }

  Future<void> _loadTeamMembers() async {
    try {
      final storesData = await Supabase.instance.client.from('stores').select('id, name, city');
      final data = await Supabase.instance.client.from('team_members').select('*, stores(name, city)').order('created_at');

      setState(() {
        _storesList = List<Map<String, dynamic>>.from(storesData);
        _teamMembers = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading team: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'profile', 'name': 'Profile', 'icon': Icons.person_outline},
      {'id': 'security', 'name': 'Security', 'icon': Icons.shield_outlined},
      if (widget.isSuperAdmin) {'id': 'team', 'name': 'Team', 'icon': Icons.people_outline},
      if (widget.isSuperAdmin) {'id': 'business', 'name': 'Business', 'icon': Icons.storefront_outlined},
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
              Text('Manage your account, team, and business preferences', style: GoogleFonts.inter(fontSize: 14, color: _subtextColor(context))),
            ]),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // --- MODERN SEGMENTED TAB SELECTOR ---
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _isDark(context) ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0).withOpacity(0.7), borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(tabs.length, (i) {
                  final sel = _tab == i;
                  return GestureDetector(
                    onTap: () => setState(() { _tab = i; _isInviting = false; }),
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
              const SizedBox(height: 32),

              if (tabs[_tab]['id'] == 'profile') _profileTab(),
              if (tabs[_tab]['id'] == 'security') _securityTab(),
              if (tabs[_tab]['id'] == 'team') _teamTab(),
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
                      DropdownButtonFormField<String>(value: _inviteRole, icon: const Icon(Icons.keyboard_arrow_down, size: 20), items: ['Manager'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14, color: _textColor(context))))).toList(), onChanged: (v) => setState(() => _inviteRole = v!), decoration: _inputDeco()),
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
                          decoration: _inputDeco()
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

          // Team List Header
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

  Widget _businessTab() {
    return _sectionCard(
        title: 'Business Settings',
        icon: Icons.storefront_outlined,
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