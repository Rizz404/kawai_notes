import 'package:objectbox/objectbox.dart';

@Entity()
class Task {
  @Id()
  int id;

  @Unique()
  String ulid;

  String title;
  bool isCompleted;

  @Property(type: PropertyType.date)
  DateTime? dueDate;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  Task({
    this.id = 0,
    required this.ulid,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
