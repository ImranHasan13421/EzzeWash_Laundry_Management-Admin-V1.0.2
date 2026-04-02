import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // ─── AUTH ───────────────────────────────────────────────────────────────
  static Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? get currentUser => _client.auth.currentUser;

  // ─── ORDERS ─────────────────────────────────────────────────────────────
  static Future<List<OrderModel>> fetchOrders() async {
    final data = await _client
        .from('orders')
        .select()
        .order('date', ascending: false);
    return (data as List).map((e) => OrderModel.fromMap(e)).toList();
  }

  static Stream<List<OrderModel>> streamOrders() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false)
        .map((list) => list.map((e) => OrderModel.fromMap(e)).toList());
  }

  static Future<OrderModel> createOrder(OrderModel order) async {
    final data = await _client
        .from('orders')
        .insert(order.toMap())
        .select()
        .single();
    return OrderModel.fromMap(data);
  }

  static Future<void> updateOrderStatus(String id, String status) async {
    await _client.from('orders').update({'status': status}).eq('id', id);
  }

  static Future<void> deleteOrder(String id) async {
    await _client.from('orders').delete().eq('id', id);
  }

  // ─── DASHBOARD STATS ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final orders = await fetchOrders();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    int total = orders.length;
    int pending = orders.where((o) => o.status == 'Pending').length;
    int received = orders.where((o) => o.status == 'Received').length;
    int completed = orders.where((o) => o.status == 'Completed').length;
    int due = orders.where((o) => o.status == 'Due').length;

    double duePayment = orders
        .where((o) => o.status == 'Due')
        .fold(0, (s, o) => s + o.price);

    double todayRevenue = orders
        .where((o) => o.date.isAfter(todayStart) && o.status == 'Completed')
        .fold(0, (s, o) => s + o.price);

    return {
      'total': total,
      'pending': pending,
      'received': received,
      'completed': completed,
      'due': due,
      'duePayment': duePayment,
      'todayRevenue': todayRevenue,
      'recentOrders': orders.take(5).toList(),
    };
  }

  // ─── REPORTS ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchReportData() async {
    final orders = await fetchOrders();
    final now = DateTime.now();

    // Build last 6 months data
    final months = <String, Map<String, dynamic>>{};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = _monthKey(m);
      months[key] = {
        'month': _monthLabel(m),
        'revenue': 0.0,
        'orders': 0,
      };
    }

    for (final o in orders) {
      final key = _monthKey(o.date);
      if (months.containsKey(key)) {
        months[key]!['revenue'] = (months[key]!['revenue'] as double) + o.price;
        months[key]!['orders'] = (months[key]!['orders'] as int) + 1;
      }
    }

    // Service breakdown
    final services = <String, int>{};
    for (final o in orders) {
      services[o.service] = (services[o.service] ?? 0) + 1;
    }

    double totalRevenue = orders
        .where((o) => o.status == 'Completed')
        .fold(0, (s, o) => s + o.price);
    int totalOrders = orders.length;

    return {
      'monthlyData': months.values.toList(),
      'services': services,
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'avgOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0,
    };
  }

  // ─── SETTINGS ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchSettings() async {
    try {
      final data = await _client
          .from('settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      return data ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _client
        .from('settings')
        .upsert({'id': 1, ...settings});
  }

  // ─── TEAM ────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchTeamMembers() async {
    try {
      final data = await _client.from('team_members').select().order('created_at');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  static Future<void> addTeamMember(Map<String, dynamic> member) async {
    await _client.from('team_members').insert(member);
  }

  static Future<void> removeTeamMember(String id) async {
    await _client.from('team_members').delete().eq('id', id);
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  static String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  static String _monthLabel(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return m[d.month - 1];
  }
}
