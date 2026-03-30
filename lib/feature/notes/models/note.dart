import 'package:objectbox/objectbox.dart';

@Entity()
class Note {
  @Id()
  int id;

  @Unique()
  String ulid;

  String title;
  String contentPath;
  List<String> tags;
  List<String> links;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Note({
    this.id = 0,
    required this.ulid,
    required this.title,
    required this.contentPath,
    this.tags = const [],
    this.links = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
