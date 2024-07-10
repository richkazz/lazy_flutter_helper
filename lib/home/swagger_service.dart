import 'package:lazy_flutter_helper/home/swagger_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SwaggerService {
  static const String storageKey = 'swagger_items';

  Future<void> addItem(SwaggerItem item) async {
    final items = await getItems();
    items.add(item);
    await _saveItems(items);
  }

  Future<List<SwaggerItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    if (jsonString != null) {
      return SwaggerItem.fromJsonList(jsonString);
    }
    return [];
  }

  Future<void> deleteItem(int id) async {
    final items = await getItems();
    items.removeWhere((item) => item.id == id);
    await _saveItems(items);
  }

  Future<void> editItem(SwaggerItem newItem) async {
    final items = await getItems();
    final index = items.indexWhere((item) => item.id == newItem.id);
    if (index != -1) {
      items[index] = newItem;
      await _saveItems(items);
    }
  }

  Future<void> _saveItems(List<SwaggerItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = SwaggerItem.toJsonList(items);
    await prefs.setString(storageKey, jsonString);
  }
}
