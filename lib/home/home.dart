import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lazy_flutter_helper/bloc_generator/bloc_generator.dart';
import 'package:lazy_flutter_helper/generator/swagger_to_dart.dart';
import 'package:lazy_flutter_helper/home/swagger_item.dart';
import 'package:lazy_flutter_helper/home/swagger_service.dart';
import 'package:lazy_flutter_helper/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SwaggerService _service = SwaggerService();
  late Future<List<SwaggerItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _service.getItems();
  }

  Future<void> _addNewItem() async {
    final newItem = await showDialog<SwaggerItem>(
      context: context,
      builder: (context) => const _AddEditItemDialog(),
    );
    if (newItem != null) {
      await _service.addItem(newItem);
      setState(() {
        _itemsFuture = _service.getItems();
      });
    }
  }

  Future<void> _editItem(SwaggerItem item) async {
    final editedItem = await showDialog<SwaggerItem>(
      context: context,
      builder: (context) => _AddEditItemDialog(item: item),
    );
    if (editedItem != null) {
      await _service.editItem(editedItem);
      setState(() {
        _itemsFuture = _service.getItems();
      });
    }
  }

  Future<void> _deleteItem(int id) async {
    await _service.deleteItem(id);
    setState(() {
      _itemsFuture = _service.getItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swagger List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewItem,
          ),
        ],
      ),
      body: FutureBuilder<List<SwaggerItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No items found.'));
          } else {
            final items = snapshot.data!;
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.swaggerJsonUrl),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editItem(item);
                      } else if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm'),
                            content:
                                const Text('Do you want to delete this item?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _deleteItem(item.id);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) {
                          return App(
                            swaggerToDart: SwaggerToDart(),
                            blocGenerator: BlocGenerator(),
                            swaggerItem: item,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

class _AddEditItemDialog extends StatefulWidget {
  const _AddEditItemDialog({this.item});
  final SwaggerItem? item;

  @override
  __AddEditItemDialogState createState() => __AddEditItemDialogState();
}

class __AddEditItemDialogState extends State<_AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _swaggerJsonUrl;
  late String _filepathToGenerate;

  @override
  void initState() {
    super.initState();
    _name = widget.item?.name ?? '';
    _swaggerJsonUrl = widget.item?.swaggerJsonUrl ?? '';
    _filepathToGenerate = widget.item?.filepathToGenerate ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              onSaved: (value) => _name = value!,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              initialValue: _swaggerJsonUrl,
              decoration: const InputDecoration(labelText: 'Swagger JSON URL'),
              onSaved: (value) => _swaggerJsonUrl = value!,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                final regex = RegExp(
                  r'^(http:\/\/localhost:\d+|https:\/\/localhost:\d+|http:\/\/[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}\/swagger\/v1\/swagger\.json|https:\/\/[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}\/swagger\/v1\/swagger\.json)$',
                );

                if (!regex.hasMatch(value)) {
                  return 'Please enter a valid url in the format https://example.com/swagger/v1/swagger.json';
                }

                return null;
              },
            ),
            TextFormField(
              initialValue: _filepathToGenerate,
              decoration:
                  const InputDecoration(labelText: 'Filepath to Generate'),
              onSaved: (value) => _filepathToGenerate = value!,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                final dosePathExist = Directory(value).existsSync();
                if (!dosePathExist) {
                  return 'The path does not exist. Please enter a valid path';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.of(context).pop(
                SwaggerItem(
                  name: _name,
                  swaggerJsonUrl: _swaggerJsonUrl,
                  filepathToGenerate: _filepathToGenerate,
                  id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch,
                ),
              );
            }
          },
          child: Text(widget.item == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
