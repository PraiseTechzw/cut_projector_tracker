// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firestore_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firestoreServiceHash() => r'0f8fc3ed9acdb2d77cdfb4f0d713961c9a50352e';

/// Provider for FirestoreService
///
/// Copied from [firestoreService].
@ProviderFor(firestoreService)
final firestoreServiceProvider = AutoDisposeProvider<FirestoreService>.internal(
  firestoreService,
  name: r'firestoreServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firestoreServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreServiceRef = AutoDisposeProviderRef<FirestoreService>;
String _$projectorsStreamHash() => r'dd6cd494288792361e48f9c84ebd472614cb6230';

/// Provider for projectors stream
///
/// Copied from [projectorsStream].
@ProviderFor(projectorsStream)
final projectorsStreamProvider =
    AutoDisposeStreamProvider<List<Projector>>.internal(
      projectorsStream,
      name: r'projectorsStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$projectorsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProjectorsStreamRef = AutoDisposeStreamProviderRef<List<Projector>>;
String _$lecturersStreamHash() => r'b3e96dd8eae95d607597dac3975616d88bbe604f';

/// Provider for lecturers stream
///
/// Copied from [lecturersStream].
@ProviderFor(lecturersStream)
final lecturersStreamProvider =
    AutoDisposeStreamProvider<List<Lecturer>>.internal(
      lecturersStream,
      name: r'lecturersStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$lecturersStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LecturersStreamRef = AutoDisposeStreamProviderRef<List<Lecturer>>;
String _$transactionsStreamHash() =>
    r'8cbdacd5bba403e3cde3083eeb8022e8ab65afb3';

/// Provider for transactions stream
///
/// Copied from [transactionsStream].
@ProviderFor(transactionsStream)
final transactionsStreamProvider =
    AutoDisposeStreamProvider<List<ProjectorTransaction>>.internal(
      transactionsStream,
      name: r'transactionsStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transactionsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TransactionsStreamRef =
    AutoDisposeStreamProviderRef<List<ProjectorTransaction>>;
String _$activeTransactionsStreamHash() =>
    r'd57eb8d76c3bc8828dd7fbbe379afbb87584c628';

/// Provider for active transactions stream
///
/// Copied from [activeTransactionsStream].
@ProviderFor(activeTransactionsStream)
final activeTransactionsStreamProvider =
    AutoDisposeStreamProvider<List<ProjectorTransaction>>.internal(
      activeTransactionsStream,
      name: r'activeTransactionsStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeTransactionsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveTransactionsStreamRef =
    AutoDisposeStreamProviderRef<List<ProjectorTransaction>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
