// lib/features/home/service_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';

class ServiceReviewsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceTitle;

  const ServiceReviewsScreen({
    super.key,
    required this.serviceId,
    required this.serviceTitle
  });

  @override
  State<ServiceReviewsScreen> createState() => _ServiceReviewsScreenState();
}

class _ServiceReviewsScreenState extends State<ServiceReviewsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];
  String _currentSort = 'Newest'; // Default sort option

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('reviews')
          .select('rating, comment, created_at, profiles(full_name), orders(order_number, total_price, created_at)')
          .eq('service_id', widget.serviceId);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(data);
          _applySort(); // Sort immediately after fetching
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // --- INSTANT LOCAL SORTING LOGIC ---
  void _applySort() {
    setState(() {
      switch (_currentSort) {
        case 'Newest':
          _reviews.sort((a, b) => (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? ''));
          break;
        case 'Oldest':
          _reviews.sort((a, b) => (a['created_at'] as String? ?? '').compareTo(b['created_at'] as String? ?? ''));
          break;
        case 'Ratings low to high':
          _reviews.sort((a, b) {
            final rA = (a['rating'] as num?)?.toDouble() ?? 0.0;
            final rB = (b['rating'] as num?)?.toDouble() ?? 0.0;
            return rA.compareTo(rB);
          });
          break;
        case 'Ratings high to low':
          _reviews.sort((a, b) {
            final rA = (a['rating'] as num?)?.toDouble() ?? 0.0;
            final rB = (b['rating'] as num?)?.toDouble() ?? 0.0;
            return rB.compareTo(rA); // Reversed for high to low
          });
          break;
      }
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'Unknown date';
    final d = DateTime.parse(isoString);
    return DateFormat('MMM d, yyyy • h:mm a').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service Reviews', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
              Text(widget.serviceTitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ]
        ),
        // --- ADDED SORT BUTTON HERE ---
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.text),
            tooltip: 'Sort By',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.surface,
            onSelected: (value) {
              _currentSort = value;
              _applySort();
            },
            itemBuilder: (BuildContext context) {
              return [
                'Newest',
                'Oldest',
                'Ratings high to low',
                'Ratings low to high',
              ].map((String choice) {
                final isSelected = _currentSort == choice;
                return PopupMenuItem<String>(
                  value: choice,
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.primary : AppColors.subtext,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                          choice,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isSelected ? AppColors.primary : AppColors.text,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                          )
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
          ? Center(child: Text('Error: $_error', style: const TextStyle(color: AppColors.error)))
          : _reviews.isEmpty
          ? Center(child: Text('No reviews yet for this service.', style: GoogleFonts.inter(color: AppColors.subtext, fontSize: 16)))
          : ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final review = _reviews[index];
          final customerName = (review['profiles'] as Map?)?['full_name'] as String? ?? 'Guest Customer';
          final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
          final comment = review['comment'] as String?;
          final order = review['orders'] as Map?;

          return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Customer & Rating Row
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(customerName[0].toUpperCase(), style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customerName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text)),
                          Text(_formatDate(review['created_at']), style: GoogleFonts.inter(fontSize: 12, color: AppColors.subtext)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      ],
                    ),
                  )
                ],
              ),

              // Comment Section
              if (comment != null && comment.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('"$comment"', style: GoogleFonts.inter(fontSize: 14, color: AppColors.text, height: 1.5, fontStyle: FontStyle.italic)),
          ],

          // Associated Order Info
          if (order != null) ...[
          const SizedBox(height: 16),
          Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
          children: [
          const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.subtext),
          const SizedBox(width: 8),
          Expanded(
          child: Text(
          'Order #${order['order_number'] ?? 'Unknown'}',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtext)
          ),
          ),
          Text(
          '৳${((order['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)
          ),
          ],
          ),
          )
          ]
          ],
          ),
          );
        },
      ),
    );
  }
}