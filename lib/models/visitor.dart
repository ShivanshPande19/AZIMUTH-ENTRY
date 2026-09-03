/// A visitor/client entry record.
///
/// IMPORTANT: this model never carries the real phone number. It only holds the
/// masked form (e.g. '98••••••10') that the database exposes to everyone. The
/// full number is fetched on demand by an owner through `reveal_phone` and is
/// never stored in this object.
class Visitor {
  final String id;
  final String name;
  final String? company;
  final String? purpose;
  final String phoneMasked;
  final DateTime entryTime;
  final DateTime? exitTime;

  const Visitor({
    required this.id,
    required this.name,
    required this.phoneMasked,
    required this.entryTime,
    this.company,
    this.purpose,
    this.exitTime,
  });

  bool get isInside => exitTime == null;

  factory Visitor.fromMap(Map<String, dynamic> map) {
    return Visitor(
      id: map['id'] as String,
      name: (map['name'] ?? '') as String,
      company: map['company'] as String?,
      purpose: map['purpose'] as String?,
      phoneMasked: (map['phone_masked'] ?? '') as String,
      entryTime: DateTime.parse(map['entry_time'] as String).toLocal(),
      exitTime: map['exit_time'] == null
          ? null
          : DateTime.parse(map['exit_time'] as String).toLocal(),
    );
  }
}
