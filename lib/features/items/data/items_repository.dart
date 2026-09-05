import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/services/cache_service.dart';
import '../domain/group_item_model.dart';
import '../../groups/data/group_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/utils/row_helpers.dart';

class ItemsRepository {
  final TablesDB _tablesDB;
  final CacheService _cacheService;
  final Ref _ref;

  ItemsRepository(this._tablesDB, this._cacheService, this._ref);

  Future<List<GroupItem>> getGroupItems(String groupId) async {
    final cached = _cacheService.getCachedShoppingItems();
    final localGroup = cached.where((i) => i.groupId == groupId).toList();

    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.listsCollection,
        queries: [
          Query.equal('groupId', groupId),
          Query.orderDesc('createdAt'),
          Query.limit(100),
        ],
      );
      final remoteItems = res.rows.map((r) => GroupItem.fromMap(r.dataWithId)).toList();
      final merged = _mergeItems(localGroup, remoteItems);
      _sortItems(merged);
      _updateTotalCache(merged);
      return merged;
    } catch (_) {
      _sortItems(localGroup);
      return localGroup;
    }
  }

  Future<List<GroupItem>> getPersonalItems(String userId) async {
    final cached = _cacheService.getCachedShoppingItems();
    final localPersonal = cached.where((i) => i.isPersonal && (i.addedBy == userId || i.addedBy.isEmpty)).toList();

    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.listsCollection,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc('createdAt'),
          Query.limit(100),
        ],
      );
      final remoteItems = res.rows
          .map((r) => GroupItem.fromMap(r.dataWithId))
          .where((i) => i.isPersonal && (i.addedBy == userId || i.addedBy.isEmpty))
          .toList();
      final merged = _mergeItems(localPersonal, remoteItems);
      _sortItems(merged);
      _updateTotalCache(merged);
      return merged;
    } catch (_) {
      _sortItems(localPersonal);
      return localPersonal;
    }
  }

  Future<List<GroupItem>> getAllItemsForUser(String userId, List<String> groupIds) async {
    final cached = _cacheService.getCachedShoppingItems();
    final localAll = cached.where((i) {
      if (i.isPersonal) {
        return i.addedBy == userId || i.addedBy.isEmpty;
      } else {
        return groupIds.contains(i.groupId);
      }
    }).toList();

    try {
      final personalItems = await getPersonalItems(userId);
      final List<GroupItem> groupItems = [];
      for (final gId in groupIds) {
        final gList = await getGroupItems(gId);
        groupItems.addAll(gList);
      }

      final merged = _mergeItems(localAll, [...personalItems, ...groupItems]);
      _sortItems(merged);
      _updateTotalCache(merged);
      return merged;
    } catch (_) {
      _sortItems(localAll);
      return localAll;
    }
  }

  List<GroupItem> _mergeItems(List<GroupItem> local, List<GroupItem> remote) {
    final map = <String, GroupItem>{};
    for (final item in local) {
      map[item.id] = item;
    }
    for (final item in remote) {
      map[item.id] = item;
    }
    return map.values.toList();
  }

  void _updateTotalCache(List<GroupItem> latest) {
    final existing = _cacheService.getCachedShoppingItems();
    final merged = _mergeItems(existing, latest);
    _cacheService.cacheShoppingItems(merged);
  }

  void _sortItems(List<GroupItem> items) {
    items.sort((a, b) {
      if (a.isBought != b.isBought) {
        return a.isBought ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<List<GroupItem>> addMultipleItems({
    required String groupId,
    required String groupName,
    required List<ItemDraft> drafts,
    required UserModel user,
  }) async {
    final validDrafts = drafts.where((d) => d.title.trim().isNotEmpty).toList();
    if (validDrafts.isEmpty) return [];

    final createdItems = <GroupItem>[];
    final isPersonal = groupId.isEmpty || groupId == 'personal';

    for (final draft in validDrafts) {
      final itemId = ID.unique();
      final newItem = GroupItem(
        id: itemId,
        groupId: isPersonal ? 'personal' : groupId,
        groupName: isPersonal ? 'Personal' : groupName,
        title: draft.title.trim(),
        quantity: draft.quantity.trim(),
        addedBy: user.id,
        addedByName: user.name.isNotEmpty ? user.name : 'User',
        isBought: false,
        createdAt: DateTime.now(),
      );

      createdItems.add(newItem);

      // Async write to Appwrite using schema compliant map
      _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.listsCollection,
        rowId: itemId,
        data: newItem.toAppwriteMap(),
      ).then((_) {}, onError: (e) {
        // Ignored or logged
      });
    }

    // Immediately cache locally
    final currentCached = _cacheService.getCachedShoppingItems();
    final updated = [...createdItems, ...currentCached];
    await _cacheService.cacheShoppingItems(updated);

    if (!isPersonal && createdItems.isNotEmpty) {
      final firstTitle = createdItems.first.title;
      final countText = createdItems.length > 1 ? ' and ${createdItems.length - 1} more items' : '';
      _notifyMembers(
        groupId: groupId,
        senderUserId: user.id,
        title: '🛒 New Items to Buy',
        body: '${user.name} added "$firstTitle"$countText to $groupName',
        type: 'list_updated',
      );
    }

    return createdItems;
  }

  Future<void> toggleItemBought({
    required GroupItem item,
    required UserModel user,
  }) async {
    final willBeBought = !item.isBought;
    final updatedItem = item.copyWith(
      isBought: willBeBought,
      boughtBy: willBeBought ? user.id : null,
      boughtByName: willBeBought ? (user.name.isNotEmpty ? user.name : 'User') : null,
      boughtAt: willBeBought ? DateTime.now() : null,
    );

    // Update local cache immediately
    final cached = _cacheService.getCachedShoppingItems();
    final updatedList = cached.map((i) => i.id == item.id ? updatedItem : i).toList();
    await _cacheService.cacheShoppingItems(updatedList);

    // Asynchronously update Appwrite
    _tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.listsCollection,
      rowId: item.id,
      data: {
        'isPurchased': willBeBought,
        'boughtBy': willBeBought ? user.id : null,
        'boughtByName': willBeBought ? (user.name.isNotEmpty ? user.name : 'User') : null,
        'boughtAt': willBeBought ? DateTime.now().toIso8601String() : null,
      },
    ).then((_) {}, onError: (_) {});

    if (willBeBought && !item.isPersonal) {
      _notifyMembers(
        groupId: item.groupId,
        senderUserId: user.id,
        title: '✅ Item Bought',
        body: '${user.name} bought "${item.title}" for ${item.groupName}',
        type: 'list_updated',
      );
    }
  }

  Future<void> deleteItem(String itemId) async {
    // Delete from cache immediately
    final cached = _cacheService.getCachedShoppingItems();
    final updatedList = cached.where((i) => i.id != itemId).toList();
    await _cacheService.cacheShoppingItems(updatedList);

    // Asynchronously delete from Appwrite
    _tablesDB.deleteRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.listsCollection,
      rowId: itemId,
    ).then((_) {}, onError: (_) {});
  }

  Future<void> _notifyMembers({
    required String groupId,
    required String senderUserId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final members = await _ref.read(groupRepositoryProvider).getGroupMembers(groupId);
      final seenUserIds = <String>{};
      final otherMembers = members
          .where((m) => m.userId != senderUserId && seenUserIds.add(m.userId))
          .toList();

      for (final m in otherMembers) {
        _tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.notificationsCollection,
          rowId: ID.unique(),
          data: {
            'userId': m.userId,
            'title': title,
            'body': body,
            'type': type,
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ).then((_) {}, onError: (_) {});
      }
    } catch (_) {}
  }
}

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepository(
    ref.watch(appwriteTablesDBProvider),
    ref.watch(cacheServiceProvider),
    ref,
  );
});

final allUserItemsProvider = FutureProvider<List<GroupItem>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final groups = ref.watch(userGroupsProvider).valueOrNull ?? [];
  final groupIds = groups.map((g) => g.id).toList();
  return ref.watch(itemsRepositoryProvider).getAllItemsForUser(user.id, groupIds);
});

final personalItemsProvider = FutureProvider<List<GroupItem>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(itemsRepositoryProvider).getPersonalItems(user.id);
});

final groupItemsProvider = FutureProvider.family<List<GroupItem>, String>((ref, groupId) async {
  return ref.watch(itemsRepositoryProvider).getGroupItems(groupId);
});
