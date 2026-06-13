import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/constants/app_constants.dart';

/// Appwrite Client provider — single instance shared across the app.
final appwriteClientProvider = Provider<Client>((ref) {
  final client = Client()
      .setEndpoint(AppConstants.appwriteEndpoint)
      .setProject(AppConstants.appwriteProjectId);
  return client;
});

/// Appwrite Account service provider.
final appwriteAccountProvider = Provider<Account>((ref) {
  return Account(ref.watch(appwriteClientProvider));
});

/// Appwrite Databases service provider.
final appwriteDatabasesProvider = Provider<Databases>((ref) {
  return Databases(ref.watch(appwriteClientProvider));
});

/// Appwrite TablesDB service provider.
final appwriteTablesDBProvider = Provider<TablesDB>((ref) {
  return TablesDB(ref.watch(appwriteClientProvider));
});

/// Appwrite Functions service provider.
final appwriteFunctionsProvider = Provider<Functions>((ref) {
  return Functions(ref.watch(appwriteClientProvider));
});

/// Appwrite Storage service provider.
final appwriteStorageProvider = Provider<Storage>((ref) {
  return Storage(ref.watch(appwriteClientProvider));
});

/// Appwrite Realtime service provider.
final appwriteRealtimeProvider = Provider<Realtime>((ref) {
  return Realtime(ref.watch(appwriteClientProvider));
});
