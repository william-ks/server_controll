import 'migration.dart';
import 'migration_v1.dart';
import 'migration_v2.dart';

class MigrationRunner {
  static final List<Migration> all = [
    MigrationV1(),
    MigrationV2(),
  ];

  static int get latestVersion => all.last.version;
}

