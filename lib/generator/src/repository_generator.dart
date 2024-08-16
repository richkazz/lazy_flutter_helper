import 'dart:io';

import 'package:lazy_flutter_helper/common/helper_mehod.dart';
import 'package:lazy_flutter_helper/generator/src/swagger_parser.dart';

class RepositoryGenerator {
  RepositoryGenerator(this.swaggerData, this.fileLocation, this.modelNamesMap);
  final SwaggerData swaggerData;
  final String fileLocation;
  final Set<String> modelNamesMap;
  final methodNamesMap = <String, int>{};
  final methodNamesAndSignatures = <String, String>{};
  void generate() {
   
    final buffer = StringBuffer();
    buffer
      ..writeln("import 'dart:developer';")
      ..writeln("import 'package:hive/hive.dart';")
      ..writeln("import 'api_service.dart';");
    buffer.writeln("import 'models/models.dart';");
    buffer.writeln("import 'package:hive_flutter/hive_flutter.dart';");

    buffer.writeln('\nclass Repository {');
    buffer.writeln('  final ApiService apiService;');
    // Generate Hive boxes for each model
    modelNamesMap.forEach((model) {
      buffer.writeln('  late Box<$model> ${model.firstLetterLowerCase()}Box;');
    });

    buffer.writeln('  Repository(this.apiService);');
    // Initialize method
    generateInitMethod(buffer);
    //generateRepositoryMethods(buffer);
    // Generate sync method
    generateSyncMethod(buffer);
    buffer.writeln('}');

    File('$fileLocation\\repository.dart').writeAsStringSync(buffer.toString());
  }

  void generateInitMethod(StringBuffer buffer) {
    buffer.writeln('\n  Future<void> init() async {');
    buffer.writeln('    await Hive.initFlutter();');
    modelNamesMap.forEach((model) {
      buffer.writeln('    Hive.registerAdapter(${model}Adapter());');
      buffer.writeln(
          '    ${model.firstLetterLowerCase()}Box = await Hive.openBox<$model>(\'${model.snakeCase()}\');');
    });
    buffer.writeln('  }');
  }

  void generateRepositoryMethods(StringBuffer buffer) {
    final paths = swaggerData.paths.forEach((path, methods) {
      methods.forEach((method, details) {
        generateRepositoryMethod(
          buffer,
          method as String,
          path,
          details as Map<String, dynamic>,
        );
      });
    });
  }

  void generateRepositoryMethod(
    StringBuffer buffer,
    String method,
    String path,
    Map<String, dynamic> details,
  ) {
    if (method != 'get') {
      return;
    }
    // Clean up the path to create a method name
    String methodName = path.replaceAll('/', '');
    methodName = methodName.replaceAll('-', '').capitalize();
    methodName = methodName[0].toLowerCase() + methodName.substring(1);
    if (methodName.contains('{')) {
      methodName = methodName.substring(0, methodName.indexOf('{'));
    }

    final summary = details['summary'];
    final responses = details['responses'] as Map<String, dynamic>;
    final requestBody = details['requestBody'];
    final parameters = details['parameters'] as List<dynamic>?;

    // Determine the return type based on the response
    String returnType = 'void';
    String throwErrorType = '';
    String parameterType = '';
    bool isArray = false;
    String returnTypeWithoutList = '';
    if (responses.containsKey('200') && responses['200']['content'] != null) {
      final content = responses['200']['content'] as Map<String, dynamic>;
      if (content.containsKey('application/json')) {
        final schema = content['application/json']['schema'];
        if (schema != null && schema['type'] == 'array') {
          isArray = true;
          if (schema != null &&
              schema['items'] != null &&
              schema['items'][r'$ref'] != null) {
            returnType = (schema['items'][r'$ref'] as String).split('/').last;
            returnTypeWithoutList = returnType;
            returnType = 'List<$returnType>';
          }
        }
        if (schema != null && schema[r'$ref'] != null) {
          returnType = (schema[r'$ref'] as String).split('/').last;
        }
      }
    }
    if (returnType == 'void') {
      return;
    }
    // get the parameterss
    final queryParameters = <String>[];
    final buildQueryString = <String>[];
    path = HelperMehods.handelParameterSettingAndPathBuilding(
      parameters,
      queryParameters,
      buildQueryString,
      path,
    );

    if (requestBody != null && requestBody['content'] != null) {
      final content = requestBody['content'] as Map<String, dynamic>;
      if (content.containsKey('application/json')) {
        final schema = content['application/json']['schema'];
        if (schema != null && schema[r'$ref'] != null) {
          parameterType = (schema[r'$ref'] as String).split('/').last;
        }
      }
    }

    if (responses.containsKey('400') && responses['400']['content'] != null) {
      final content = responses['400']['content'] as Map<String, dynamic>;
      if (content.containsKey('application/problem+json')) {
        final schema = content['application/problem+json']['schema'];
        if (schema != null && schema[r'$ref'] != null) {
          throwErrorType = (schema[r'$ref'] as String).split('/').last;
        }
      }
    }

    if (responses.containsKey('401') && responses['401']['content'] != null) {
      final content = responses['401']['content'] as Map<String, dynamic>;
      if (content.containsKey('application/problem+json')) {
        final schema = content['application/problem+json']['schema'];
        if (schema != null && schema[r'$ref'] != null) {
          throwErrorType = (schema[r'$ref'] as String).split('/').last;
        }
      }
    }

    buffer.writeln('  // $summary');
    if (parameterType.isNotEmpty) {
      queryParameters.add('required $parameterType request');
    }
    //Determine if the method name already exists
    //Then Generate a unique name
    if (methodNamesMap.containsKey(methodName)) {
      final newFeq = methodNamesMap[methodName]! + 1;
      methodName = '$methodName$newFeq';
      methodNamesMap.addAll({methodName: newFeq});
    } else {
      methodNamesMap.addAll({methodName: 1});
    }
    var methodSignature = '';
    if (queryParameters.isNotEmpty) {
      methodSignature =
          '  Future<${HelperMehods.getReturnType(throwErrorType, returnType)}> $methodName({${queryParameters.join(', ')}}) async {';
    } else {
      methodSignature =
          '  Future<${HelperMehods.getReturnType(throwErrorType, returnType)}> $methodName() async {';
    }
    methodNamesAndSignatures.addAll({methodName: methodSignature.trim()});
    buffer..writeln(methodSignature);
    buffer.writeln('    try {');

    // Local-first approach: Check local storage
    if (isArray) {
      buffer.writeln(
          "      final localData = await  _${returnType.camelCase}Box.get('$methodName');");
    } else {
      buffer.writeln(
          "      final localData = await  _${returnType.camelCase}Box.get('$methodName');");
    }

    buffer.writeln('      if (localData != null) {');
    if (isArray) {
      buffer.writeln(
        '        final List<$returnTypeWithoutList> localResult = (localData as List).map((item) => $returnTypeWithoutList.fromMap(item as Map<String, dynamic>)).toList();',
      );
    } else if (returnType != 'void') {
      buffer.writeln(
        '        final localResult = $returnType.fromMap(localData as  Map<String, dynamic>);',
      );
    }
    buffer.writeln(
      '        return ${HelperMehods.getReturnType(throwErrorType, returnType)}(data: ${returnType != 'void' ? 'localResult' : 'null'}, isSuccess: true, isFromCache: true);',
    );
    buffer
      ..writeln('      }')
      ..writeln()

      // API call
      ..writeln('      // Fetch from API if not in local storage');
    final queryArguments = <String>[];
    for (final param in queryParameters) {
      final paramName = param.split(' ').last;
      queryArguments.add('$paramName: $paramName');
    }
    if (queryParameters.isNotEmpty) {
      buffer.writeln(
        '      final result = await _apiService.$methodName(${queryArguments.join(', ')});',
      );
    } else {
      buffer.writeln('      final result = await _apiService.$methodName();');
    }

    // Save to local storage if successful
    if (returnType != 'void') {
      buffer.writeln('      if (result.isSuccess && result.data != null) {');
      if (isArray) {
        buffer.writeln(
            '        await _${returnTypeWithoutList.camelCase}Box.putAll({for (var item in result.data!) item.id: item});');
      } else {
        buffer.writeln(
            '        await _${returnType.camelCase}Box.put(result.data!.data.id, result.data!);');
      }
    } else {
      buffer.writeln('      if (result.isSuccess) {');
    }

    buffer
      ..writeln('      }')

      // Return result
      ..writeln('      return result;')

      // Error handling
      ..writeln('    } catch (error, stacktrace) {')
      ..writeln(r"      log('Error: $error');")
      ..writeln(r"      log('Stacktrace: $stacktrace');")
      ..writeln('      rethrow;')
      ..writeln('    }')
      ..writeln('  }');
  }

  void generateSyncMethod(StringBuffer buffer) {
    buffer.writeln('\n  Future<void> syncOfflineOperations() async {');
    buffer.writeln('    final offlineQueue = Hive.box<Map>(\'offlineQueue\');');
    buffer.writeln('    for (var i = 0; i < offlineQueue.length; i++) {');
    buffer.writeln('      final operation = offlineQueue.getAt(i);');
    buffer.writeln('      if (operation != null) {');
    buffer.writeln('        try {');
    buffer.writeln(
        '          final method = operation[\'methodName\'] as String;');
    buffer.writeln(
        '          final params = operation[\'params\'] as Map<String, dynamic>;');
    buffer.writeln(
        '          await (this as dynamic).callMethod(Symbol(method), [], params);');
    buffer.writeln('          await offlineQueue.deleteAt(i);');
    buffer.writeln('          i--;  // Decrement i because we removed an item');
    buffer.writeln('        } catch (e) {');
    buffer
        .writeln('          print(\'Error syncing offline operation: \$e\');');
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln('    }');
    buffer.writeln('  }');

    buffer.writeln(
        '\n  Future<void> _queueOfflineOperation(String methodName, Map<String, dynamic> params) async {');
    buffer.writeln('    final offlineQueue = Hive.box<Map>(\'offlineQueue\');');
    buffer.writeln('    await offlineQueue.add({');
    buffer.writeln('      \'methodName\': methodName,');
    buffer.writeln('      \'params\': params,');
    buffer.writeln('      \'timestamp\': DateTime.now().toIso8601String(),');
    buffer.writeln('    });');
    buffer.writeln('  }');
  }
}
