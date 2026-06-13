import 'package:appwrite/models.dart' as models;

/// Extension on [models.Row] to provide data with $id merged in.
/// The Appwrite TablesDB Row model stores $id separately from data,
/// but our domain models expect $id inside the map.
extension RowDataWithId on models.Row {
  /// Returns the row data with '\$id' merged in from the Row object.
  Map<String, dynamic> get dataWithId => {...data, '\$id': $id};
}
