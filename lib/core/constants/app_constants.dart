// lib/core/constants/app_constants.dart
class AppConstants {
  AppConstants._();

  static const supabaseUrl = 'https://xxvicmprwtbxinuluyqx.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_RGFSfrrMcY-uqQrFxNCNaw_Z6D6Jmo2';

  // Tables (same as customer + rider apps)
  static const ordersTable         = 'orders';
  static const profilesTable       = 'profiles';
  static const ridersTable         = 'riders';
  static const servicesTable       = 'services';
  static const storesTable         = 'stores';
  static const orderTimelinesTable = 'order_timelines';

  // Admin role — set this in user_metadata when creating admin accounts
  static const adminRole = 'admin';

  // Order statuses
  static const statusPending         = 'pending';
  static const statusConfirmed       = 'confirmed';
  static const statusPickedUp        = 'picked_up';
  static const statusInProcess       = 'in_process';
  static const statusReady           = 'ready';
  static const statusOutForDelivery  = 'out_for_delivery';
  static const statusDelivered       = 'delivered';
  static const statusCancelled       = 'cancelled';
}
