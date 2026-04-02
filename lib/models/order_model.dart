class OrderModel {
  final String? id;
  final String customer;
  final String phone;
  final String address;
  final String service;
  final String branch;
  final double price;
  final double quantity;
  final String notes;
  String status;
  final DateTime date;
  final String? orderId;

  OrderModel({
    this.id,
    required this.customer,
    required this.phone,
    this.address = '',
    required this.service,
    required this.branch,
    required this.price,
    this.quantity = 1,
    this.notes = '',
    required this.status,
    required this.date,
    this.orderId,
  });

  String get displayId => orderId ?? (id != null ? 'ORD-${id!.substring(0, 8).toUpperCase()}' : 'ORD-NEW');

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id']?.toString(),
      orderId: map['order_id']?.toString(),
      customer: map['customer'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      service: map['service'] ?? '',
      branch: map['branch'] ?? '',
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num? ?? 1).toDouble(),
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'Pending',
      date: DateTime.parse(map['date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'customer': customer,
      'phone': phone,
      'address': address,
      'service': service,
      'branch': branch,
      'price': price,
      'quantity': quantity,
      'notes': notes,
      'status': status,
      'date': date.toIso8601String(),
    };
  }

  OrderModel copyWith({String? status}) {
    return OrderModel(
      id: id,
      orderId: orderId,
      customer: customer,
      phone: phone,
      address: address,
      service: service,
      branch: branch,
      price: price,
      quantity: quantity,
      notes: notes,
      status: status ?? this.status,
      date: date,
    );
  }
}
