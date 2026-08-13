import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> getDatabase() async {
  final appDocumentDir = await getApplicationDocumentsDirectory();
  final dbPath = join(appDocumentDir.path, 'eagleflow.db');
  final databaseFactory = databaseFactoryIo;
  return await databaseFactory.openDatabase(dbPath, version: 1);
}
