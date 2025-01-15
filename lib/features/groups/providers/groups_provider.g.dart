// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'groups_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$groupsHash() => r'75520c8500a0d2f3e897d138de3b34b8e71e363b';

/// See also [Groups].
@ProviderFor(Groups)
final groupsProvider =
    AutoDisposeAsyncNotifierProvider<Groups, List<GroupModel>>.internal(
  Groups.new,
  name: r'groupsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$groupsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Groups = AutoDisposeAsyncNotifier<List<GroupModel>>;
String _$groupsSearchHash() => r'183dd24433c6552a07ae4a66740fb95d6883ecf8';

/// See also [GroupsSearch].
@ProviderFor(GroupsSearch)
final groupsSearchProvider =
    AutoDisposeNotifierProvider<GroupsSearch, String>.internal(
  GroupsSearch.new,
  name: r'groupsSearchProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$groupsSearchHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GroupsSearch = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
