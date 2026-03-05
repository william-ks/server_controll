import 'migration.dart';
import 'migration_v1.dart';
import 'migration_v2.dart';
import 'migration_v3.dart';
import 'migration_v4.dart';
import 'migration_v5.dart';

class MigrationRunner {
  static final List<Migration> all = [
    MigrationV1(),
    MigrationV2(),
    MigrationV3(),
    MigrationV4(),
    MigrationV5(),
  ];

  static int get latestVersion => all.last.version;
}
