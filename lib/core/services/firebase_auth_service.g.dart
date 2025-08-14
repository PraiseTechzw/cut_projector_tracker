// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_auth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseAuthServiceHash() =>
    r'932f2366f20e06e26bf8aba16cd27209742e9bb9';

/// Provider for FirebaseAuthService
///
/// Copied from [firebaseAuthService].
@ProviderFor(firebaseAuthService)
final firebaseAuthServiceProvider =
    AutoDisposeProvider<FirebaseAuthService>.internal(
      firebaseAuthService,
      name: r'firebaseAuthServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$firebaseAuthServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthServiceRef = AutoDisposeProviderRef<FirebaseAuthService>;
String _$authStateChangesHash() => r'89d565e17fc6bdc58e70b5bbcbc52f47ca977080';

/// Provider for current user
///
/// Copied from [authStateChanges].
@ProviderFor(authStateChanges)
final authStateChangesProvider = AutoDisposeStreamProvider<User?>.internal(
  authStateChanges,
  name: r'authStateChangesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateChangesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateChangesRef = AutoDisposeStreamProviderRef<User?>;
String _$currentUserHash() => r'3fbeb700132efc5f122dc6a87bea920c1cee4915';

/// Provider for current user (nullable)
///
/// Copied from [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeProvider<User?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserRef = AutoDisposeProviderRef<User?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
