import 'package:objectbox/objectbox.dart';

@Entity()
class Folder {
  @Id()
  int id;

  String name;
  int? parentId;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  Folder({this.id = 0, required this.name, this.parentId, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();
}
