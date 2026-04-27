import 'package:kawai_notes/feature/folders/models/folder.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Note {
  @Id()
  int id;

  @Unique()
  String ulid;

  String title;
  String contentPath;
  String? content;
  List<String> tags;
  List<String> links;

  bool isHidden;
  bool isPinned;
  bool isDeleted;

  int? colorValue;
  String? customBackgroundImage;

  final folder = ToOne<Folder>();

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Note({
    this.id = 0,
    required this.ulid,
    required this.title,
    required this.contentPath,
    this.content,
    this.tags = const [],
    this.links = const [],
    this.isHidden = false,
    this.isPinned = false,
    this.isDeleted = false,
    this.colorValue,
    this.customBackgroundImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
