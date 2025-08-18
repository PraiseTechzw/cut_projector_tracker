import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a projector transaction (issuance/return)
class ProjectorTransaction {
  final String id;
  final String projectorId;
  final String lecturerId;
  final String projectorSerialNumber;
  final String lecturerName;
  final String status;
  final DateTime dateIssued;
  final DateTime? dateReturned;
  final String? purpose;
  final String? notes;
  final String? returnNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectorTransaction({
    required this.id,
    required this.projectorId,
    required this.lecturerId,
    required this.projectorSerialNumber,
    required this.lecturerName,
    required this.status,
    required this.dateIssued,
    this.dateReturned,
    this.purpose,
    this.notes,
    this.returnNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a ProjectorTransaction from Firestore document
  factory ProjectorTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectorTransaction(
      id: doc.id,
      projectorId: data['projectorId'] ?? '',
      lecturerId: data['lecturerId'] ?? '',
      projectorSerialNumber: data['projectorSerialNumber'] ?? '',
      lecturerName: data['lecturerName'] ?? '',
      status: data['status'] ?? 'Active',
      dateIssued: data['dateIssued'] != null
          ? (data['dateIssued'] as Timestamp).toDate()
          : DateTime.now(),
      dateReturned: data['dateReturned'] != null
          ? (data['dateReturned'] as Timestamp).toDate()
          : null,
      purpose: data['purpose'],
      notes: data['notes'],
      returnNotes: data['returnNotes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert ProjectorTransaction to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'projectorId': projectorId,
      'lecturerId': lecturerId,
      'projectorSerialNumber': projectorSerialNumber,
      'lecturerName': lecturerName,
      'status': status,
      'dateIssued': Timestamp.fromDate(dateIssued),
      'dateReturned': dateReturned != null
          ? Timestamp.fromDate(dateReturned!)
          : null,
      'purpose': purpose,
      'notes': notes,
      'returnNotes': returnNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy of ProjectorTransaction with updated fields
  ProjectorTransaction copyWith({
    String? id,
    String? projectorId,
    String? lecturerId,
    String? projectorSerialNumber,
    String? lecturerName,
    String? status,
    DateTime? dateIssued,
    DateTime? dateReturned,
    String? purpose,
    String? notes,
    String? returnNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectorTransaction(
      id: id ?? this.id,
      projectorId: projectorId ?? this.projectorId,
      lecturerId: lecturerId ?? this.lecturerId,
      projectorSerialNumber:
          projectorSerialNumber ?? this.projectorSerialNumber,
      lecturerName: lecturerName ?? this.lecturerName,
      status: status ?? this.status,
      dateIssued: dateIssued ?? this.dateIssued,
      dateReturned: dateReturned ?? this.dateReturned,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      returnNotes: returnNotes ?? this.returnNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if transaction is active (projector not returned)
  bool get isActive => status == 'Active';

  /// Check if transaction is completed (projector returned)
  bool get isCompleted => status == 'Returned';

  /// Get duration of the transaction
  Duration? get duration {
    if (dateReturned != null) {
      return dateReturned!.difference(dateIssued);
    }
    return DateTime.now().difference(dateIssued);
  }

  /// Get formatted duration string
  String get durationString {
    final dur = duration;
    if (dur == null) return 'N/A';

    final days = dur.inDays;
    final hours = dur.inHours % 24;
    final minutes = dur.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  String toString() {
    return 'ProjectorTransaction(id: $id, projector: $projectorSerialNumber, lecturer: $lecturerName, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectorTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
