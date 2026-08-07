import 'package:sembast_web/sembast_web.dart';

Future<Database> getDatabase() async {
  final databaseFactory = databaseFactoryWeb;
  return await databaseFactory.openDatabase('eagleflow_web.db', version: 1);
}
