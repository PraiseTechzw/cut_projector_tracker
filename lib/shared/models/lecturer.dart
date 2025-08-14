import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a lecturer in the system
class Lecturer {
  final String id;
  final String name;
  final String department;
  final String email;
  final String? phoneNumber;
  final String? employeeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lecturer({
    required this.id,
    required this.name,
    required this.department,
    required this.email,
    this.phoneNumber,
    this.employeeId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a Lecturer from Firestore document
  factory Lecturer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lecturer(
      id: doc.id,
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      employeeId: data['employeeId'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert Lecturer to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'department': department,
      'email': email,
      'phoneNumber': phoneNumber,
      'employeeId': employeeId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy of Lecturer with updated fields
  Lecturer copyWith({
    String? id,
    String? name,
    String? department,
    String? email,
    String? phoneNumber,
    String? employeeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lecturer(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      employeeId: employeeId ?? this.employeeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display name with department
  String get displayName => '$name ($department)';

  @override
  String toString() {
    return 'Lecturer(id: $id, name: $name, department: $department, email: $email, phoneNumber: $phoneNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lecturer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
