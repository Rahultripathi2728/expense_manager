import 'package:appwrite/appwrite.dart';

void main() async {
  Client client = Client()
    .setEndpoint('https://sgp.cloud.appwrite.io/v1')
    .setProject('6a200c97000d20071b44')
    .setSelfSigned(status: true);

  Databases databases = Databases(client);

  try {
    final result = await databases.listDocuments(
      databaseId: 'expense_manager_db',
      collectionId: 'notifications',
    );
    print('Found ${result.total} notifications.');
    for (var doc in result.documents) {
      print('Notification: ${doc.data}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
