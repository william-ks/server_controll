abstract class Migration {
  int get version;
  Future<void> up(dynamic db);
}

