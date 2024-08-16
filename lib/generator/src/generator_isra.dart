import 'dart:io';
import 'package:lazy_flutter_helper/common/helper_mehod.dart';
import 'package:lazy_flutter_helper/generator/swagger_to_dart.dart';

import 'swagger_parser.dart';

class DartGenerator {
  DartGenerator(this.swaggerData, this.fileLocation);
  final SwaggerData swaggerData;
  final String fileLocation;
  final modelNamesMap = <String>{};
  final enumNamesMap = <String>{};
  final enumNamesAndDefinitions = <String, String>{};
  final modelNamesAndDefinitionsMap = <String, String>{};
  final methodNamesMap = <String, int>{};
  final methodNamesAndSignatures = <String, String>{};

  SwaggerToDartResult generate() {
    generateModels();
    generateService();
    return SwaggerToDartResult(
      modelsNames: modelNamesMap.toList(),
      enumNames: enumNamesMap.toList(),
      methodNames: methodNamesMap.keys.toList(),
      enumNamesAndDefinitions: enumNamesAndDefinitions,
      methodNamesAndSignatures: methodNamesAndSignatures,
      modelNamesAndDefinitionsMap: modelNamesAndDefinitionsMap,
    );
  }

  void fillTheNameSets(Map<String, dynamic> components) {
    components.forEach((name, schema) {
      if ((schema as Map<String, dynamic>).containsKey('enum')) {
        enumNamesMap.add(name);
      } else {
        modelNamesMap.add(name);
      }
    });
  }

  void generateModels() {
    final bufferModel = StringBuffer();
    final bufferEnum = StringBuffer();

    final components =
        swaggerData.components['schemas'] as Map<String, dynamic>;
    fillTheNameSets(components);
    components.forEach((name, schema) async {
      String fileName;
      if ((schema as Map<String, dynamic>).containsKey('enum')) {
        fileName = generateEnum(name, schema);
        final doesFileExist =
            File('$fileLocation\\enums\\${name.snakeCase()}_extension.dart')
                .existsSync();
        if (!doesFileExist) {
          generateEnumExtension(name, schema);
        }
        bufferEnum.writeln("export '${name.snakeCase()}.dart';");
        bufferEnum.writeln("export '${name.snakeCase()}_extension.dart';");
      } else {
        fileName = generateModel(name, schema);
        bufferModel.writeln("export '$fileName';");
      }
    });
    final file = File('$fileLocation\\models\\models.dart');
    file.writeAsStringSync(bufferModel.toString());
    final fileEnum = File('$fileLocation\\enums\\enums.dart');
    fileEnum.writeAsStringSync(bufferEnum.toString());
  }

  String generateEnum(String name, Map<String, dynamic> schema) {
    final className = name.capitalize();
    final buffer = StringBuffer();
    buffer.writeln('enum $className {');
    final fields = schema['enum'] as List<dynamic>;
    for (var field in fields) {
      buffer.writeln('  ${field.toString().snakeCase()},');
    }
    buffer.writeln('}');
    File('$fileLocation\\enums\\${name.snakeCase()}.dart')
        .writeAsStringSync(buffer.toString());
    return '${name.snakeCase()}.dart';
  }

  String generateEnumExtension(String name, Map<String, dynamic> schema) {
    final className = name.capitalize();
    final buffer = StringBuffer()
      ..writeln("import '../enums/enums.dart';")
      ..writeln('extension ${className}Extension on $className {')
      ..writeln("  String get name => toString().split('.').last;")
      ..writeln('}');

    File('$fileLocation\\enums\\${name.snakeCase()}_extension.dart')
        .writeAsStringSync(buffer.toString());
    return '${name.snakeCase()}.dart';
  }

  String generateModel(String name, Map<String, dynamic> schema) {
    final className = name.capitalize();
    final fields = schema['properties'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    buffer.writeln("import 'package:isar/isar.dart';");
    buffer.writeln("import 'dart:convert';");
    buffer.writeln();
    buffer.writeln('@collection');
    buffer.writeln('class $className {');

    fields.forEach((fieldName, fieldSchema) {
      String fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final isList = fieldType.startsWith('List');
      if (isList) {
        fieldType = fieldType.replaceAll('List<', '').replaceAll('>', '');
      }
      if (enumNamesMap.contains(fieldType)) {
        buffer.writeln("  late $fieldType $fieldName;");
      } else if (modelNamesMap.contains(fieldType)) {
        buffer.writeln("  late $fieldType $fieldName;");
      } else {
        buffer.writeln("  late ${fieldType} $fieldName;");
      }
    });

    buffer.writeln();
    defineIsarModelFunctions(buffer, className, fields);

    buffer.writeln('}');
    File('$fileLocation\\models\\${name.snakeCase()}.dart')
        .writeAsStringSync(buffer.toString());

    return '${name.snakeCase()}.dart';
  }

  void defineIsarModelFunctions(
    StringBuffer buffer,
    String className,
    Map<String, dynamic> fields,
  ) {
    // Define the fromMap, toMap, fromJson, toJson methods for Isar
    buffer
      ..writeln('  $className fromMap(Map<String, dynamic> map) {')
      ..writeln('    return $className(');

    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      buffer.writeln("      $fieldName: map['$fieldName'],");
    });

    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer
      ..writeln()
      ..writeln('  Map<String, dynamic> toMap() {')
      ..writeln('    return {');

    fields.forEach((fieldName, fieldSchema) {
      buffer.writeln("      '$fieldName': $fieldName,");
    });

    buffer
      ..writeln('    };')
      ..writeln('  }');

    buffer
      ..writeln()
      ..writeln(
          '  $className fromJson(String source) => fromMap(json.decode(source) as Map<String, dynamic>);')
      ..writeln()
      ..writeln('  String toJson() => json.encode(toMap());');
  }

  String getFieldType(Map<String, dynamic> fieldSchema) {
    if (fieldSchema.containsKey(r'$ref')) {
      return (fieldSchema[r'$ref'] as String).split('/').last;
    } else if (fieldSchema['type'] == 'array') {
      // if (fieldSchema['items'].containsKey('\$ref')) {
      //   return 'List<${fieldSchema['items']['\$ref'].split('/').last}>';
      // }
      final typeInList =
          getFieldType(fieldSchema['items'] as Map<String, dynamic>);
      return 'List<$typeInList>';
    }
    {
      return mapSwaggerTypeToDart(fieldSchema['type'] as String?);
    }
  }

  void defineEmptyStaticConstructor(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    //static const LoginRequest empty = LoginRequest(
    //email: '', password: '', twoFactorCode: '', twoFactorRecoveryCode: '');
    buffer
      ..writeln()
      ..writeln('  static const $className empty = $className(');
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final isList =
          mapSwaggerTypeToDart(fieldSchema['type'] as String?) == 'List';
      if (modelNamesMap.contains(fieldType)) {
        buffer.writeln('    $fieldName: $fieldType.empty,');
      } else if (enumNamesMap.contains(fieldType)) {
        buffer.writeln('    $fieldName: $fieldType.none,');
      } else if (isList) {
        buffer.writeln('    $fieldName: [],');
      } else {
        buffer.writeln(
          '    $fieldName: ${mapSwaggerTypeToDartConstantValue(fieldSchema['type'] as String?)},',
        );
      }
    });
    buffer
      ..writeln('  );')
      ..writeln('  bool get isEmpty => this == $className.empty;')
      ..writeln('  bool get isNotEmpty => this != $className.empty;');
  }

  void defineToJson(StringBuffer buffer) {
    buffer.writeln();
    buffer.writeln('  String toJson() => json.encode(toMap());');
  }

  void defineCopyWith(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    buffer.writeln();
    buffer.writeln('  $className copyWith({');
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      buffer.writeln(
        '    $fieldType${fieldType == 'dynamic' ? '' : '?'} $fieldName,',
      );
    });
    buffer.writeln('  }) {');
    buffer.writeln('    return $className(');
    fields.forEach((fieldName, fieldSchema) {
      buffer.writeln('      $fieldName: $fieldName ?? this.$fieldName,');
    });
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  void defineToMap(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    buffer
      ..writeln()
      ..writeln('  Map<String, dynamic> toMap() {')
      ..writeln('    return {');
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      if (modelNamesMap.contains(fieldType)) {
        buffer.writeln("      '$fieldName': $fieldName.toMap(),");
      } else if (enumNamesMap.contains(fieldType)) {
        buffer.writeln("      '$fieldName': $fieldName.index,");
      } else {
        buffer.writeln("      '$fieldName': $fieldName,");
      }
    });
    buffer
      ..writeln('    };')
      ..writeln('  }');
  }

  void defineFromJson(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    buffer
      ..writeln()
      ..writeln(
        '  factory $className.fromJson(String source) => $className.fromMap(json.decode(source) as Map<String, dynamic>);',
      );
  }

  void defineFromMap(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    final bufferModelDescription = StringBuffer()
      ..writeln('Model Name: $className|')
      ..write(' Fields Name:type: ');
    buffer.writeln();
    buffer.writeln('  factory $className.fromMap(Map<String, dynamic> map,) {');
    buffer.writeln('    return $className(');
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final nullable = HelperMehods.isFieldTypeNull(fieldSchema) ? '?' : '';
      final isList =
          mapSwaggerTypeToDart(fieldSchema['type'] as String?) == 'List';
      if (isList) {
        var fieldTypeRemoveList = fieldType.replaceAll('List', '');
        fieldTypeRemoveList = fieldTypeRemoveList.replaceAll('<', '');
        fieldTypeRemoveList = fieldTypeRemoveList.replaceAll('>', '');
        if (modelNamesMap.contains(fieldTypeRemoveList)) {
          if (nullable == '?') {
            buffer.writeln("$fieldName: map['$fieldName'] == null");
            buffer.writeln('? null');
            buffer.writeln(": (map['$fieldName'] as List<dynamic>)");
            buffer.writeln(
              '.map((e) => $fieldTypeRemoveList.fromMap(e as Map<String, dynamic>))',
            );
            buffer.writeln('.toList(),');
            bufferModelDescription.write('$fieldName: $fieldTypeRemoveList|');
          } else {
            buffer.writeln("$fieldName: (map['$fieldName'] as List<dynamic>)");
            buffer.writeln(
              '.map((e) => $fieldTypeRemoveList.fromMap(e as Map<String, dynamic>))',
            );
            buffer.writeln('.toList(),');
            bufferModelDescription.write('$fieldName: $fieldTypeRemoveList|');
          }
        } else {
          buffer.writeln(
            "      $fieldName:map['$fieldName'] == null ? null :  $fieldType.from(map['$fieldName'] as List<dynamic>),",
          );
          bufferModelDescription.write('$fieldName: $fieldTypeRemoveList|');
        }
      } else if (modelNamesMap.contains(fieldType)) {
        buffer.writeln(
          "      $fieldName: map['$fieldName'] == null ? $fieldType.empty : $fieldType.fromMap(map['$fieldName'] as Map<String, dynamic>),",
        );
        bufferModelDescription.write('$fieldName: $fieldType|');
      } else if (enumNamesMap.contains(fieldType)) {
        buffer.writeln(
          "      $fieldName: $fieldType.values[map['$fieldName']  as int],",
        );
        bufferModelDescription.write('$fieldName: $fieldType|');
      } else {
        buffer.writeln(
          "      $fieldName: map['$fieldName'] as $fieldType$nullable,",
        );
        bufferModelDescription.write('$fieldName: $fieldType|');
      }
    });
    buffer
      ..writeln('    );')
      ..writeln('  }');
    bufferModelDescription.write(
        '  Methods: fromMap,toJson,fromJson,toMap,empty,isEmpty,isNotEmpty');
    modelNamesAndDefinitionsMap[className] = bufferModelDescription.toString();
  }

  void defineConstructor(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    buffer
      ..writeln()
      ..writeln('  const $className({');
    fields.forEach((fieldName, fieldSchema) {
      final isRequired =
          HelperMehods.isFieldTypeNull(fieldSchema as Map<String, dynamic>)
              ? ''
              : 'required ';
      buffer.writeln('    $isRequired this.$fieldName,');
    });
    buffer.writeln('  });');
  }

  void defineFields(StringBuffer buffer, Map<String, dynamic> fields) {
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final nullable = HelperMehods.isFieldTypeNull(fieldSchema) ? '?' : '';
      buffer.writeln('  final $fieldType$nullable $fieldName;');
    });
  }

  String mapSwaggerTypeToDart(String? type) {
    switch (type) {
      case 'string':
        return 'String';
      case 'integer':
        return 'int';
      case 'number':
        return 'double';
      case 'boolean':
        return 'bool';
      case 'array':
        return 'List'; // You might need to handle array of specific types
      default:
        return 'dynamic';
    }
  }

  String mapSwaggerTypeToDartConstantValue(String? type) {
    switch (type) {
      case 'string':
        return "''";
      case 'integer':
        return '0';
      case 'number':
        return '0.0';
      case 'boolean':
        return 'false';
      default:
        return 'null';
    }
  }

  void generateResultClass(StringBuffer buffer) {
    buffer
      ..writeln('class Result<T, E> {')
      ..writeln('  T? data;')
      ..writeln('  E? errorData;')
      ..writeln('  bool isSuccess;')
      ..writeln()
      ..writeln('  Result({')
      ..writeln('    this.data,')
      ..writeln('    this.errorData,')
      ..writeln('    required this.isSuccess,')
      ..writeln('  });')
      ..writeln()
      ..writeln('  Result<T, E> copyWith({')
      ..writeln('    T? data,')
      ..writeln('    bool? isSuccess,')
      ..writeln('    E? errorData')
      ..writeln('  }) {')
      ..writeln('    return Result<T, E>(')
      ..writeln('      data: data ?? this.data,')
      ..writeln('      isSuccess: isSuccess ?? this.isSuccess,')
      ..writeln('      errorData: errorData ?? this.errorData')
      ..writeln('    );')
      ..writeln('  }')
      ..writeln('}');
  }

  void generateExceptionClass(StringBuffer buffer) {
    buffer.writeln('class UnAuthorizedException implements Exception {}');
  }

  void generateService() {
    final buffer = StringBuffer()
      ..writeln("import 'dart:convert';")
      ..writeln("import 'dart:developer';")
      ..writeln("import 'package:http/http.dart' as http;")
      ..writeln("import 'models/models.dart';")
      ..writeln("import 'http_client_call.dart';");
    generateExceptionClass(buffer);
    generateResultClass(buffer);
    buffer
      ..writeln('class ApiService {')
      ..writeln('  ApiService({required this.httpClientCall});')
      ..writeln('  final HttpClientCall httpClientCall;');

    final paths = swaggerData.paths;
    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        generateServiceMethod(
          buffer,
          method as String,
          path,
          details as Map<String, dynamic>,
        );
      });
    });

    buffer.writeln('}');
    if (!File('$fileLocation\\http_client_call.dart').existsSync()) {
      File('$fileLocation\\http_client_call.dart')
          .writeAsStringSync(generateHttpClientCall());
    }
    File('$fileLocation\\api_service.dart')
        .writeAsStringSync(buffer.toString());
  }

  void generateServiceMethod(
    StringBuffer buffer,
    String method,
    String path,
    Map<String, dynamic> details,
  ) {
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
    // get the parameters
    final queryParameters = <String>[];
    final buildQueryString = <String>[];
    path = handelParameterSettingAndPathBuilding(
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
          '  Future<${getReturnType(throwErrorType, returnType)}> $methodName({${queryParameters.join(', ')}}) async {';
    } else {
      methodSignature =
          '  Future<${getReturnType(throwErrorType, returnType)}> $methodName() async {';
    }
    methodNamesAndSignatures.addAll({methodName: methodSignature.trim()});
    buffer
      ..writeln(methodSignature)
      ..writeln('    try {');
    if (parameterType.isNotEmpty) {
      buffer.writeln(
        "      final response = await  httpClientCall.$method('$path', body: request.toJson());",
      );
    } else {
      buffer.writeln(
        "      final response = await  httpClientCall.$method('$path');",
      );
    }

    buffer.writeln('      switch (response.statusCode) {');
    for200(buffer, returnType, returnTypeWithoutList, throwErrorType, isArray);
    for401(buffer, returnType, returnTypeWithoutList, throwErrorType, isArray);
    for400(buffer, returnType, returnTypeWithoutList, throwErrorType, isArray);

    // Handle other responses
    buffer
      ..writeln('        default:')
      ..writeln(
        r"          throw Exception('Unexpected error: ${response.statusCode} ${response.body}');",
      )
      ..writeln('      }')
      ..writeln('    } catch (error, stacktrace) {')
      ..writeln(r"      log('Error: $error');")
      ..writeln(r"      log('Stacktrace: $stacktrace');")
      ..writeln('      rethrow;')
      ..writeln('    }')
      ..writeln('  }');
  }

  String handelParameterSettingAndPathBuilding(
    List<dynamic>? parameters,
    List<String> queryParameters,
    List<String> buildQueryString,
    String path,
  ) {
    if (parameters != null) {
      for (var i = 0; i < parameters.length; i++) {
        final parameter = parameters[i] as Map<String, dynamic>;
        if (parameter['in'] == 'path') {
          final type =
              mapSwaggerTypeToDart(parameter['schema']['type'] as String);
          final name = parameter['name'];
          queryParameters.add('required $type $name');
          continue;
        }
        if (parameter['in'] == 'query') {
          final type =
              mapSwaggerTypeToDart(parameter['schema']['type'] as String);
          final name = parameter['name'];
          queryParameters.add('required $type $name');
          buildQueryString.add('${parameter['name']}=\$$name');
          continue;
        }
      }
    }
    if (buildQueryString.isNotEmpty) {
      path = '$path?${buildQueryString.join('&')}';
    }

    path = path.replaceAll('{', r'$');
    path = path.replaceAll('}', '');
    return path;
  }

  void for401(
    StringBuffer buffer,
    String returnType,
    String returnTypeWithoutList,
    String throwErrorType,
    bool isArray,
  ) {
    buffer.writeln('        case 401:');
    buffer.writeln('          throw UnAuthorizedException();');
  }

  void for400(
    StringBuffer buffer,
    String returnType,
    String returnTypeWithoutList,
    String throwErrorType,
    bool isArray,
  ) {
    if (throwErrorType.isNotEmpty) {
      buffer.writeln('        case 400:');
      buffer.writeln(
        '          final result = $throwErrorType.fromJson(response.body);',
      );
      buffer.writeln(
        '          return ${getReturnType(throwErrorType, returnType)}(errorData: result, isSuccess: true);',
      );
    } else {
      buffer.writeln('        case 400:');
      buffer.writeln(
        r"          throw Exception('Bad request: ${response.body}');",
      );
    }
  }

  void for200(
    StringBuffer buffer,
    String returnType,
    String returnTypeWithoutList,
    String throwErrorType,
    bool isArray,
  ) {
    // Handle 200 response
    if (returnType != 'void') {
      buffer.writeln('        case 200:');
      if (isArray) {
        buffer.writeln(
          '          final result = (json.decode(response.body) as List<dynamic>).map((e) => $returnTypeWithoutList.fromMap(e as Map<String, dynamic>)).toList();',
        );
      } else {
        buffer.writeln(
          '          final result = $returnType.fromJson(response.body);',
        );
      }
      buffer.writeln(
        '          return ${getReturnType(throwErrorType, returnType)}(data: result, isSuccess: true);',
      );
    } else {
      buffer
        ..writeln('        case 200:')
        ..writeln(
          '          return ${getReturnType(throwErrorType, returnType)}(isSuccess: true);',
        );
    }
  }

  String getReturnType(String errorType, String returnType) {
    if (returnType == 'void' && errorType.isNotEmpty) {
      return 'Result<void,$errorType>';
    } else if (returnType == 'void' && errorType.isEmpty) {
      return 'Result<void,void>';
    } else if (returnType != 'void' && errorType.isEmpty) {
      return 'Result<$returnType,void>';
    } else {
      return 'Result<$returnType,$errorType>';
    }
  }

  String generateHttpClientCall() {
    final buffer = StringBuffer()
      ..writeln("import 'package:http/http.dart' as http;")
      ..writeln()
      ..writeln('class HttpClientCall {')
      ..writeln('  HttpClientCall({')
      ..writeln('    required this.handelJsonToken,')
      ..writeln('    required this.baseUrl,')
      ..writeln('    String? token,')
      ..writeln('  }) {')
      ..writeln('    if (token != null) {')
      ..writeln(r"      headers['Authorization'] = 'Bearer $token';")
      ..writeln('    }')
      ..writeln('  }')
      ..writeln('  final HandelJsonToken handelJsonToken;')
      ..writeln('  final String baseUrl;')
      ..writeln('  void updateToken(String token) {')
      ..writeln(r"    headers['Authorization'] = 'Bearer $token';")
      ..writeln('  }')
      ..writeln()
      ..writeln('  void removeToken() {')
      ..writeln("    headers.remove('Authorization');")
      ..writeln('  }')
      ..writeln()
      ..writeln('  Map<String, String> headers = {')
      ..writeln("    'Content-Type': 'application/json',")
      ..writeln('  };')
      ..writeln(
          '  Future<http.Response> get(String url, {Map<String, String>? headers}) async {')
      ..writeln(
          r'    final response = await http.get(Uri.parse($baseUrl$url), headers: {...this.headers, ...?headers});')
      ..writeln('    if (response.statusCode == 401) {')
      ..writeln('      final result = await refreshToken();')
      ..writeln('      if (result) {')
      ..writeln(
          r'        final response = await http.get(Uri.parse($baseUrl$url), headers: {...this.headers, ...?headers});')
      ..writeln('        return response;')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return response;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  Future<bool> refreshToken() async {')
      ..writeln(
          '    final refreshToken = await handelJsonToken.getRefreshToken;')
      ..writeln('    if (refreshToken != null) {')
      ..writeln(
          '      final request = RefreshRequest(refreshToken: refreshToken);')
      ..writeln('      final response = await http.post(')
      ..writeln(r"        Uri.parse('$baseUrl/refresh'),")
      ..writeln("        headers: {'Content-Type': 'application/json'},")
      ..writeln('        body: request.toJson(),')
      ..writeln('      );')
      ..writeln('      if (response.statusCode == 200) {')
      ..writeln(
          '        final result = AccessTokenResponse.fromJson(response.body);')
      ..writeln(
          '        await handelJsonToken.setJsonToken(result.accessToken);')
      ..writeln(
          '        await handelJsonToken.setRefreshToken(result.refreshToken);')
      ..writeln(
          r"        headers['Authorization'] = 'Bearer ${result.accessToken}';")
      ..writeln('        return true;')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return false;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  Future<http.Response> post(String url, {')
      ..writeln('    Map<String, String>? headers,')
      ..writeln('    String? body,')
      ..writeln('  }) async {')
      ..writeln('    final response = await http.post(')
      ..writeln(r"      Uri.parse('$baseUrl$url'),")
      ..writeln('      headers: {...this.headers, ...?headers},')
      ..writeln('      body: body,')
      ..writeln('    );')
      ..writeln('    if (response.statusCode == 401) {')
      ..writeln('      final result = await refreshToken();')
      ..writeln('      if (result) {')
      ..writeln('        final response = await http.post(')
      ..writeln(r"          Uri.parse('$baseUrl$url'),")
      ..writeln('          headers: {...this.headers, ...?headers},')
      ..writeln('          body: body,')
      ..writeln('        );')
      ..writeln('        return response;')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return response;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  Future<http.Response> put(String url, {')
      ..writeln('    Map<String, String>? headers,')
      ..writeln('    String? body,')
      ..writeln('  }) async {')
      ..writeln('    final response = await http.put(')
      ..writeln(r"      Uri.parse('$baseUrl$url'),")
      ..writeln('      headers: {...this.headers, ...?headers},')
      ..writeln('      body: body,')
      ..writeln('    );')
      ..writeln('    if (response.statusCode == 401) {')
      ..writeln('      final result = await refreshToken();')
      ..writeln('      if (result) {')
      ..writeln('        final response = await http.put(')
      ..writeln(r"      Uri.parse('$baseUrl$url'),")
      ..writeln('          headers: {...this.headers, ...?headers},')
      ..writeln('          body: body,')
      ..writeln('        );')
      ..writeln('        return response;')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return response;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  Future<http.Response> delete(String url, {')
      ..writeln('    Map<String, String>? headers,')
      ..writeln('  }) async {')
      ..writeln('    final response = await http.delete(')
      ..writeln(r"      Uri.parse('$baseUrl$url'),")
      ..writeln('      headers: {...this.headers, ...?headers},')
      ..writeln('    );')
      ..writeln('    if (response.statusCode == 401) {')
      ..writeln('      final result = await refreshToken();')
      ..writeln('      if (result) {')
      ..writeln('        final response = await http.delete(')
      ..writeln(r"          Uri.parse('$baseUrl$url'),")
      ..writeln('          headers: {...this.headers, ...?headers},')
      ..writeln('        );')
      ..writeln('        return response;')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return response;')
      ..writeln('  }')
      ..writeln('}');
    return buffer.toString();
  }
}
