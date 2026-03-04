import 'migration.dart';
import 'migration_v1.dart';

class MigrationRunner {
  static final List<Migration> all = [
    MigrationV1(),
  ];

  static int get latestVersion => all.last.version;
}
