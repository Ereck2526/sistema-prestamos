class Client {
  final String id;
  final String name;
  final String? phone;
  final String? alias;
  final DateTime? createdAt;

  Client({
    required this.id,
    required this.name,
    this.phone,
    this.alias,
    this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      alias: json['alias'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'alias': alias,
    };
  }
}
