// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingInvitationsHash() =>
    r'f82541b256b93398c201ce958c4a89bdf6d08016';

/// See also [pendingInvitations].
@ProviderFor(pendingInvitations)
final pendingInvitationsProvider =
    AutoDisposeStreamProvider<List<GroupInvitation>>.internal(
  pendingInvitations,
  name: r'pendingInvitationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingInvitationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingInvitationsRef
    = AutoDisposeStreamProviderRef<List<GroupInvitation>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
