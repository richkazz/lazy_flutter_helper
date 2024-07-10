import 'dart:convert';

class SwaggerItem {
  SwaggerItem({
    required this.name,
    required this.swaggerJsonUrl,
    required this.filepathToGenerate,
    required this.id,
  });

  factory SwaggerItem.fromJson(Map<String, dynamic> json) {
    return SwaggerItem(
      name: json['name'] as String,
      swaggerJsonUrl: json['swaggerJsonUrl'] as String,
      filepathToGenerate: json['filepathToGenerate'] as String,
      id: json['id'] as int,
    );
  }
  String name;
  String swaggerJsonUrl;
  String filepathToGenerate;
  int id;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'swaggerJsonUrl': swaggerJsonUrl,
      'filepathToGenerate': filepathToGenerate,
      'id': id,
    };
  }

  static List<SwaggerItem> fromJsonList(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((item) => SwaggerItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String toJsonList(List<SwaggerItem> items) {
    final list = items.map((item) => item.toJson()).toList();
    return json.encode(list);
  }
}
