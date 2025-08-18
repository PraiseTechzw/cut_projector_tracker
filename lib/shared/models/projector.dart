import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a projector in the system
class Projector {
  final String id;
  final String serialNumber;
  final String modelName;
  final String projectorName;
  final String status;
  final String? location;
  final String? notes;
  final String? lastIssuedTo;
  final DateTime? lastIssuedDate;
  final DateTime? lastReturnDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Projector({
    required this.id,
    required this.serialNumber,
    required this.modelName,
    required this.projectorName,
    required this.status,
    this.location,
    this.notes,
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
      modelName: data['modelName'] ?? '',
      projectorName: data['projectorName'] ?? '',
      status: data['status'] ?? 'Available',
      location: data['location'],
      notes: data['notes'],
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
      'modelName': modelName,
      'projectorName': projectorName,
      'status': status,
      'location': location,
      'notes': notes,
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
    String? modelName,
    String? projectorName,
    String? status,
    String? location,
    String? notes,
    String? lastIssuedTo,
    DateTime? lastIssuedDate,
    DateTime? lastReturnDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Projector(
      id: id ?? this.id,
      serialNumber: serialNumber ?? this.serialNumber,
      modelName: modelName ?? this.modelName,
      projectorName: projectorName ?? this.projectorName,
      status: status ?? this.status,
      location: location ?? this.location,
      notes: notes ?? this.notes,
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
