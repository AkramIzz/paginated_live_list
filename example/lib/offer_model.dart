import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String? id;
  final String author;
  final int price;
  final DateTime availableUntil;
  final DateTime createdAt;

  Offer({
    required this.id,
    required this.author,
    required this.price,
    required this.availableUntil,
    required this.createdAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'],
      author: json['author'],
      price: json['price'],
      availableUntil: (json['availableUntil'] as Timestamp).toDate(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'price': price,
      'availableUntil': Timestamp.fromDate(availableUntil),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Offer copyWith({
    dynamic id = _CopyWithKeepSentinel.value,
    dynamic createdBy = _CopyWithKeepSentinel.value,
    dynamic price = _CopyWithKeepSentinel.value,
    dynamic availableUnitl = _CopyWithKeepSentinel.value,
    dynamic createdAt = _CopyWithKeepSentinel.value,
  }) {
    T _resolveValue<T>(dynamic update, T original) {
      return update == _CopyWithKeepSentinel.value ? original : update;
    }

    return Offer(
      id: _resolveValue(id, this.id),
      author: _resolveValue(createdBy, this.author),
      price: _resolveValue(price, this.price),
      availableUntil: _resolveValue(availableUnitl, this.availableUntil),
      createdAt: _resolveValue(createdAt, this.createdAt),
    );
  }
}

class _CopyWithKeepSentinel {
  const _CopyWithKeepSentinel();

  static const value = _CopyWithKeepSentinel();
}
