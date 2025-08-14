import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a projector in the system
class Projector {
  final String id;
  final String serialNumber;
  final String status;
  final String? lastIssuedTo;
  final DateTime? lastIssuedDate;
  final DateTime? lastReturnDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Projector({
    required this.id,
    required this.serialNumber,
    required this.status,
    this.lastIssuedTo,
    this.lastIssuedDate,
    this.lastReturnDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a Projector from Firestore document
  factory Projector.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Projector(
      id: doc.id,
      serialNumber: data['serialNumber'] ?? '',
      status: data['status'] ?? 'Available',
      lastIssuedTo: data['lastIssuedTo'],
      lastIssuedDate: data['lastIssuedDate'] != null
          ? (data['lastIssuedDate'] as Timestamp).toDate()
          : null,
      lastReturnDate: data['lastReturnDate'] != null
          ? (data['lastReturnDate'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert Projector to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'serialNumber': serialNumber,
      'status': status,
      'lastIssuedTo': lastIssuedTo,
      'lastIssuedDate': lastIssuedDate != null
          ? Timestamp.fromDate(lastIssuedDate!)
          : null,
      'lastReturnDate': lastReturnDate != null
          ? Timestamp.fromDate(lastReturnDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy of Projector with updated fields
  Projector copyWith({
    String? id,
    String? serialNumber,
    String? status,
    String? lastIssuedTo,
    DateTime? lastIssuedDate,
    DateTime? lastReturnDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Projector(
      id: id ?? this.id,
      serialNumber: serialNumber ?? this.serialNumber,
      status: status ?? this.status,
      lastIssuedTo: lastIssuedTo ?? this.lastIssuedTo,
      lastIssuedDate: lastIssuedDate ?? this.lastIssuedDate,
      lastReturnDate: lastReturnDate ?? this.lastReturnDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if projector is available
  bool get isAvailable => status == 'Available';

  /// Check if projector is issued
  bool get isIssued => status == 'Issued';

  /// Check if projector is under maintenance
  bool get isMaintenance => status == 'Maintenance';

  @override
  String toString() {
    return 'Projector(id: $id, serialNumber: $serialNumber, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Projector && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
