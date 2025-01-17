// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'groups_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firestoreServiceHash() => r'0f8fc3ed9acdb2d77cdfb4f0d713961c9a50352e';

/// See also [firestoreService].
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
String _$groupsHash() => r'f0f1d3ce3356360360c9c91f5f9eb1d60c7b7aa0';

/// See also [Groups].
@ProviderFor(Groups)
final groupsProvider =
    AutoDisposeStreamNotifierProvider<Groups, List<GroupModel>>.internal(
  Groups.new,
  name: r'groupsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$groupsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Groups = AutoDisposeStreamNotifier<List<GroupModel>>;
String _$filteredGroupsHash() => r'7dd9f208e261f448161d4a448ed69e87c29bf11a';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$FilteredGroups
    extends BuildlessAutoDisposeStreamNotifier<List<GroupModel>> {
  late final String searchQuery;

  Stream<List<GroupModel>> build(
    String searchQuery,
  );
}

/// See also [FilteredGroups].
@ProviderFor(FilteredGroups)
const filteredGroupsProvider = FilteredGroupsFamily();

/// See also [FilteredGroups].
class FilteredGroupsFamily extends Family<AsyncValue<List<GroupModel>>> {
  /// See also [FilteredGroups].
  const FilteredGroupsFamily();

  /// See also [FilteredGroups].
  FilteredGroupsProvider call(
    String searchQuery,
  ) {
    return FilteredGroupsProvider(
      searchQuery,
    );
  }

  @override
  FilteredGroupsProvider getProviderOverride(
    covariant FilteredGroupsProvider provider,
  ) {
    return call(
      provider.searchQuery,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'filteredGroupsProvider';
}

/// See also [FilteredGroups].
class FilteredGroupsProvider extends AutoDisposeStreamNotifierProviderImpl<
    FilteredGroups, List<GroupModel>> {
  /// See also [FilteredGroups].
  FilteredGroupsProvider(
    String searchQuery,
  ) : this._internal(
          () => FilteredGroups()..searchQuery = searchQuery,
          from: filteredGroupsProvider,
          name: r'filteredGroupsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$filteredGroupsHash,
          dependencies: FilteredGroupsFamily._dependencies,
          allTransitiveDependencies:
              FilteredGroupsFamily._allTransitiveDependencies,
          searchQuery: searchQuery,
        );

  FilteredGroupsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.searchQuery,
  }) : super.internal();

  final String searchQuery;

  @override
  Stream<List<GroupModel>> runNotifierBuild(
    covariant FilteredGroups notifier,
  ) {
    return notifier.build(
      searchQuery,
    );
  }

  @override
  Override overrideWith(FilteredGroups Function() create) {
    return ProviderOverride(
      origin: this,
      override: FilteredGroupsProvider._internal(
        () => create()..searchQuery = searchQuery,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        searchQuery: searchQuery,
      ),
    );
  }

  @override
  AutoDisposeStreamNotifierProviderElement<FilteredGroups, List<GroupModel>>
      createElement() {
    return _FilteredGroupsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredGroupsProvider && other.searchQuery == searchQuery;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, searchQuery.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FilteredGroupsRef
    on AutoDisposeStreamNotifierProviderRef<List<GroupModel>> {
  /// The parameter `searchQuery` of this provider.
  String get searchQuery;
}

class _FilteredGroupsProviderElement
    extends AutoDisposeStreamNotifierProviderElement<FilteredGroups,
        List<GroupModel>> with FilteredGroupsRef {
  _FilteredGroupsProviderElement(super.provider);

  @override
  String get searchQuery => (origin as FilteredGroupsProvider).searchQuery;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
