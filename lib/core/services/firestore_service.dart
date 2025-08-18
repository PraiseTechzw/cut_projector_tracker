import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../shared/models/projector.dart';
import '../../shared/models/lecturer.dart';
import '../../shared/models/transaction.dart';
import '../constants/app_constants.dart';

part 'firestore_service.g.dart';

/// Service for handling Firestore database operations
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Projectors Collection
  CollectionReference<Map<String, dynamic>> get _projectorsCollection =>
      _firestore.collection(AppConstants.projectorsCollection);

  // Lecturers Collection
  CollectionReference<Map<String, dynamic>> get _lecturersCollection =>
      _firestore.collection(AppConstants.lecturersCollection);

  // Transactions Collection
  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection(AppConstants.transactionsCollection);

  // PROJECTOR OPERATIONS

  /// Get all projectors
  Stream<List<Projector>> getProjectors() {
    return _projectorsCollection
        .orderBy('serialNumber')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Projector.fromFirestore(doc)).toList(),
        );
  }

  /// Get projector by ID
  Future<Projector?> getProjectorById(String id) async {
    try {
      final doc = await _projectorsCollection.doc(id).get();
      if (doc.exists) {
        return Projector.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to get projector: $e';
    }
  }

  /// Get projector by serial number
  Future<Projector?> getProjectorBySerialNumber(String serialNumber) async {
    try {
      final query = await _projectorsCollection
          .where('serialNumber', isEqualTo: serialNumber)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Projector.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw 'Failed to get projector: $e';
    }
  }

  /// Add new projector
  Future<String> addProjector(Projector projector) async {
    try {
      final docRef = await _projectorsCollection.add(projector.toFirestore());
      return docRef.id;
    } catch (e) {
      throw 'Failed to add projector: $e';
    }
  }

  /// Update projector
  Future<void> updateProjector(Projector projector) async {
    try {
      await _projectorsCollection
          .doc(projector.id)
          .update(projector.toFirestore());
    } catch (e) {
      throw 'Failed to update projector: $e';
    }
  }

  /// Delete projector
  Future<void> deleteProjector(String id) async {
    try {
      await _projectorsCollection.doc(id).delete();
    } catch (e) {
      throw 'Failed to delete projector: $e';
    }
  }

  // LECTURER OPERATIONS

  /// Get all lecturers
  Stream<List<Lecturer>> getLecturers() {
    return _lecturersCollection
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Lecturer.fromFirestore(doc)).toList(),
        );
  }

  /// Get lecturer by ID
  Future<Lecturer?> getLecturerById(String id) async {
    try {
      final doc = await _lecturersCollection.doc(id).get();
      if (doc.exists) {
        return Lecturer.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to get lecturer: $e';
    }
  }

  /// Search lecturers by name or department
  Future<List<Lecturer>> searchLecturers(String query) async {
    try {
      final nameQuery = await _lecturersCollection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '$query\uf8ff')
          .get();

      final deptQuery = await _lecturersCollection
          .where('department', isGreaterThanOrEqualTo: query)
          .where('department', isLessThan: '$query\uf8ff')
          .get();

      final allDocs = {...nameQuery.docs, ...deptQuery.docs};
      return allDocs
          .map((doc) => Lecturer.fromFirestore(doc))
          .toList()
          .toSet()
          .toList(); // Remove duplicates
    } catch (e) {
      throw 'Failed to search lecturers: $e';
    }
  }

  /// Add new lecturer
  Future<String> addLecturer(Lecturer lecturer) async {
    try {
      final docRef = await _lecturersCollection.add(lecturer.toFirestore());
      return docRef.id;
    } catch (e) {
      throw 'Failed to add lecturer: $e';
    }
  }

  /// Update lecturer
  Future<void> updateLecturer(Lecturer lecturer) async {
    try {
      await _lecturersCollection
          .doc(lecturer.id)
          .update(lecturer.toFirestore());
    } catch (e) {
      throw 'Failed to update lecturer: $e';
    }
  }

  /// Delete lecturer
  Future<void> deleteLecturer(String lecturerId) async {
    try {
      await _lecturersCollection.doc(lecturerId).delete();
    } catch (e) {
      throw 'Failed to delete lecturer: $e';
    }
  }

  // TRANSACTION OPERATIONS

  /// Get all transactions
  Stream<List<ProjectorTransaction>> getTransactions() {
    return _transactionsCollection
        .orderBy('dateIssued', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProjectorTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get active transactions
  Stream<List<ProjectorTransaction>> getActiveTransactions() {
    return _transactionsCollection
        .where('status', isEqualTo: AppConstants.transactionActive)
        .orderBy('dateIssued', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProjectorTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get transactions by projector ID
  Stream<List<ProjectorTransaction>> getTransactionsByProjector(
    String projectorId,
  ) {
    return _transactionsCollection
        .where('projectorId', isEqualTo: projectorId)
        .orderBy('dateIssued', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProjectorTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get transactions by lecturer ID
  Stream<List<ProjectorTransaction>> getTransactionsByLecturer(
    String lecturerId,
  ) {
    return _transactionsCollection
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('dateIssued', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProjectorTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  /// Add new transaction
  Future<String> addTransaction(ProjectorTransaction transaction) async {
    try {
      final docRef = await _transactionsCollection.add(
        transaction.toFirestore(),
      );
      return docRef.id;
    } catch (e) {
      throw 'Failed to add transaction: $e';
    }
  }

  /// Update transaction
  Future<void> updateTransaction(ProjectorTransaction transaction) async {
    try {
      await _transactionsCollection
          .doc(transaction.id)
          .update(transaction.toFirestore());
    } catch (e) {
      throw 'Failed to update transaction: $e';
    }
  }

  /// Issue projector (create transaction and update projector status)
  Future<void> issueProjector({
    required String projectorId,
    required String lecturerId,
    required String projectorSerialNumber,
    required String lecturerName,
    String? purpose,
    String? notes,
  }) async {
    try {
      final batch = _firestore.batch();

      // Create transaction
      final transaction = ProjectorTransaction(
        id: '', // Will be set by Firestore
        projectorId: projectorId,
        lecturerId: lecturerId,
        projectorSerialNumber: projectorSerialNumber,
        lecturerName: lecturerName,
        status: AppConstants.transactionActive,
        dateIssued: DateTime.now(),
        purpose: purpose,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final transactionRef = _transactionsCollection.doc();
      batch.set(transactionRef, transaction.toFirestore());

      // Update projector status
      final projectorRef = _projectorsCollection.doc(projectorId);
      batch.update(projectorRef, {
        'status': AppConstants.statusIssued,
        'lastIssuedTo': lecturerName,
        'lastIssuedDate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      throw 'Failed to issue projector: $e';
    }
  }

  /// Return projector (update transaction and projector status)
  Future<void> returnProjector({
    required String transactionId,
    required String projectorId,
    String? returnNotes,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update transaction
      final transactionRef = _transactionsCollection.doc(transactionId);
      batch.update(transactionRef, {
        'status': AppConstants.transactionReturned,
        'dateReturned': Timestamp.now(),
        'returnNotes': returnNotes,
        'updatedAt': Timestamp.now(),
      });

      // Update projector status
      final projectorRef = _projectorsCollection.doc(projectorId);
      batch.update(projectorRef, {
        'status': AppConstants.statusAvailable,
        'lastReturnDate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      throw 'Failed to return projector: $e';
    }
  }
}

/// Provider for FirestoreService
@riverpod
FirestoreService firestoreService(FirestoreServiceRef ref) {
  return FirestoreService();
}

/// Provider for projectors stream
@riverpod
Stream<List<Projector>> projectorsStream(ProjectorsStreamRef ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getProjectors();
}

/// Provider for lecturers stream
@riverpod
Stream<List<Lecturer>> lecturersStream(LecturersStreamRef ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getLecturers();
}

/// Provider for transactions stream
@riverpod
Stream<List<ProjectorTransaction>> transactionsStream(
  TransactionsStreamRef ref,
) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getTransactions();
}

/// Provider for active transactions stream
@riverpod
Stream<List<ProjectorTransaction>> activeTransactionsStream(
  ActiveTransactionsStreamRef ref,
) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getActiveTransactions();
}
