
import 'package:sembast/sembast_memory.dart';

Future<Database> getDatabase() async {
  return await databaseFactoryMemory.openDatabase('eagleflow_io.db', version: 1);
}
