class RoomSummaryData {
  const RoomSummaryData({
    required this.id,
    required this.name,
    required this.roomType,
    required this.location,
    required this.isActive,
  });

  final int id;
  final String name;
  final String roomType;
  final String location;
  final bool isActive;

  factory RoomSummaryData.fromJson(Map<String, dynamic> json) {
    return RoomSummaryData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: (json['name'] ?? '').toString(),
      roomType: (json['room_type'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      isActive: (json['is_active'] ?? false).toString() == 'true' || json['is_active'] == 1,
    );
  }
}
