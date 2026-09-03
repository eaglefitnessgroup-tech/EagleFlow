
import 'package:sembast/sembast_memory.dart';

Future<Database> getDatabase() async {
  return await databaseFactoryMemory.openDatabase('eagleflow_web.db', version: 1);
}
