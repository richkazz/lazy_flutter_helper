import 'dart:io';
import 'package:lazy_flutter_helper/common/helper_mehod.dart';
import 'package:lazy_flutter_helper/generator/src/repository_generator.dart';
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
    //RepositoryGenerator(swaggerData, fileLocation, modelNamesMap).generate();
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
        final doseFileExist =
            File('$fileLocation\\enums\\${name.snakeCase()}_extension.dart')
                .existsSync();
        if (!doseFileExist) {
          generateEnumExtension(name, schema);
        }
        bufferEnum.writeln("export '${name.snakeCase()}.dart';");
        bufferEnum.writeln("export '${name.snakeCase()}_extension.dart';");
      } else {
        fileName = generateModel(name, schema);
        bufferModel.writeln("export '$fileName';");
      }
    });
    generateEnumAdapterRegistration();
    File('$fileLocation\\models\\models.dart')
        .writeAsStringSync(bufferModel.toString());
    File('$fileLocation\\enums\\enums.dart')
        .writeAsStringSync(bufferEnum.toString());
  }

  void generateEnumAdapterRegistration() {
    final buffer = StringBuffer()
      ..writeln("import 'package:hive/hive.dart';")
      ..writeln("import 'enums.dart';")
      ..writeln()
      ..writeln('void registerEnumAdapters() {');
    enumNamesMap.forEach((enumName) {
      buffer.writeln('  Hive.registerAdapter(${enumName}Adapter());');
    });
    buffer.writeln('}');

    File('$fileLocation\\enums\\enum_adapters.dart')
        .writeAsStringSync(buffer.toString());
  }

  bool isFieldTypeNull(Map<String, dynamic> fieldSchema) {
    late bool isNull;
    final fieldType =
        HelperMehods.mapSwaggerTypeToDart(fieldSchema['type'] as String?);
    if (fieldType == 'int') {
      isNull = fieldSchema['format'] != 'int64';
    } else if (fieldType == 'dynamic') {
      isNull = false;
    } else {
      isNull = fieldSchema['nullable'] == true;
    }
    return isNull;
  }

  String generateEnum(String name, Map<String, dynamic> schema) {
    final className = name.capitalize();
    final buffer = StringBuffer();
    final bufferDescription = StringBuffer()..writeln('enum name: $className|');

    buffer.writeln("import 'package:hive/hive.dart';");
    buffer.writeln();
    buffer.writeln(
        '@HiveType(typeId: ${enumNamesMap.indexOf(name) + modelNamesMap.length})');
    buffer.writeln('enum $className {');
    bufferDescription.write('enum fields:');

    final fields = schema['enum'] as List<dynamic>;
    for (var i = 0; i < fields.length; i++) {
      final field = fields[i] as String;
      buffer.writeln('  @HiveField($i)');
      buffer.write('  ${field.firstLetterLowerCase()}');
      bufferDescription.write('$field|');
      if (i != fields.length - 1) {
        buffer.write(',');
      } else {
        buffer
          ..write(',')
          ..writeln('  @HiveField(${fields.length})')
          ..writeln('  none;');
      }
      buffer.writeln();
    }

    buffer.writeln();
    for (var i = 0; i < fields.length; i++) {
      final field = fields[i] as String;
      buffer.writeln(
        'bool get is$field => this == $className.${field.firstLetterLowerCase()};',
      );
    }
    buffer.writeln('}');

    // Generate enum adapter
    generateEnumAdapter(buffer, className, fields);

    File('$fileLocation\\enums\\${name.snakeCase()}.dart')
        .writeAsStringSync(buffer.toString());
    enumNamesAndDefinitions[className] = bufferDescription.toString();
    return '${name.snakeCase()}.dart';
  }

  void generateEnumAdapter(
      StringBuffer buffer, String className, List<dynamic> fields) {
    buffer
      ..writeln()
      ..writeln('class ${className}Adapter extends TypeAdapter<$className> {')
      ..writeln('  @override')
      ..writeln(
          '  final int typeId = ${enumNamesMap.indexOf(className) + modelNamesMap.length};')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  $className read(BinaryReader reader) {')
      ..writeln('    switch (reader.readByte()) {');
    for (var i = 0; i < fields.length; i++) {
      final field = fields[i] as String;
      buffer.writeln('      case $i:');
      buffer.writeln(
          '        return $className.${field.firstLetterLowerCase()};');
    }
    buffer.writeln('      default:');
    buffer.writeln('        return $className.none;');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  void write(BinaryWriter writer, $className obj) {');
    buffer.writeln('    switch (obj) {');
    for (var i = 0; i < fields.length; i++) {
      final field = fields[i] as String;
      buffer.writeln('      case $className.${field.firstLetterLowerCase()}:');
      buffer.writeln('        writer.writeByte($i);');
      buffer.writeln('        break;');
    }
    buffer.writeln('      case $className.none:');
    buffer.writeln('        writer.writeByte(${fields.length});');
    buffer.writeln('        break;');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  String generateEnumExtension(String name, Map<String, dynamic> schema) {
    final className = name.capitalize();
    final buffer = StringBuffer();
    buffer
      ..writeln("import '../enums/enums.dart';")
      ..writeln('extension ${className}Extension on $className {}');
    final file =
        File('$fileLocation\\enums\\${name.snakeCase()}_extension.dart');
    file.writeAsStringSync(buffer.toString());
    return '${name.snakeCase()}.dart';
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
      return HelperMehods.mapSwaggerTypeToDart(fieldSchema['type'] as String?);
    }
  }

  String generateModel(String name, Map<String, dynamic> schema) {
    final className = name.capitalize();
    final fields = schema['properties'] as Map<String, dynamic>;

    final buffer = StringBuffer()
      ..writeln("import 'package:hive/hive.dart';")
      ..writeln("import 'dart:convert';");
    fields.forEach((fieldName, fieldSchema) {
      String fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final isList =
          HelperMehods.mapSwaggerTypeToDart(fieldSchema['type'] as String?) ==
              'List';
      if (isList) {
        fieldType = fieldType.replaceAll('List', '');
        fieldType = fieldType.replaceAll('<', '');
        fieldType = fieldType.replaceAll('>', '');
      }
      if (enumNamesMap.contains(fieldType)) {
        buffer.writeln("import '../enums/enums.dart';");
      }
      if (modelNamesMap.contains(fieldType)) {
        buffer.writeln("import '${fieldType.snakeCase()}.dart';");
      }
    });
    buffer
      ..writeln()
      ..writeln(
          '@HiveType(typeId: ${modelNamesMap.toList().indexOf(className)})')
      ..writeln('class $className extends HiveObject {');
    // Constructor
    defineConstructor(buffer, fields, className);
    // fromMap factory constructor
    defineFromMap(buffer, fields, className);

    // fromJson factory constructor
    defineFromJson(buffer, fields, className);

    // toMap method
    defineToMap(buffer, fields, className);

    // toJson method
    defineToJson(buffer);

    // copyWith method
    defineCopyWith(buffer, fields, className);

    // Define fields
    defineFields(buffer, fields);

    defineEmptyStaticConstructor(buffer, fields, className);

    buffer.writeln('}');

    // Generate Hive adapter
    generateHiveAdapter(buffer, className, fields);

    File('$fileLocation\\models\\${name.snakeCase()}.dart')
        .writeAsStringSync(buffer.toString());

    return '${name.snakeCase()}.dart';
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
      ..writeln('  static $className empty = $className(');
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final isList =
          HelperMehods.mapSwaggerTypeToDart(fieldSchema['type'] as String?) ==
              'List';
      if (modelNamesMap.contains(fieldType)) {
        buffer.writeln('    $fieldName: $fieldType.empty,');
      } else if (enumNamesMap.contains(fieldType)) {
        buffer.writeln('    $fieldName: $fieldType.none,');
      } else if (isList) {
        buffer.writeln('    $fieldName: [],');
      } else {
        buffer.writeln(
          '    $fieldName: ${HelperMehods.mapSwaggerTypeToDartConstantValue(fieldSchema['type'] as String?)},',
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
      final nullable = isFieldTypeNull(fieldSchema) ? '?' : '';
      final isList =
          HelperMehods.mapSwaggerTypeToDart(fieldSchema['type'] as String?) ==
              'List';
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
      '  Methods: fromMap,toJson,fromJson,toMap,empty,isEmpty,isNotEmpty',
    );
    modelNamesAndDefinitionsMap[className] = bufferModelDescription.toString();
  }

  void defineConstructor(
    StringBuffer buffer,
    Map<String, dynamic> fields,
    String className,
  ) {
    buffer
      ..writeln()
      ..writeln('  $className({');
    fields.forEach((fieldName, fieldSchema) {
      final isRequired = isFieldTypeNull(fieldSchema as Map<String, dynamic>)
          ? ''
          : 'required ';
      buffer.writeln('    $isRequired this.$fieldName,');
    });
    buffer.writeln('  });');
  }

  void defineFields(StringBuffer buffer, Map<String, dynamic> fields) {
    var fieldIndex = 0;
    fields.forEach((fieldName, fieldSchema) {
      final fieldType = getFieldType(fieldSchema as Map<String, dynamic>);
      final nullable = isFieldTypeNull(fieldSchema) ? '?' : '';
      buffer
        ..writeln('@HiveField($fieldIndex)')
        ..writeln('  final $fieldType$nullable $fieldName;');
      fieldIndex++;
    });
  }

  void generateHiveAdapter(
    StringBuffer buffer,
    String className,
    Map<String, dynamic> fields,
  ) {
    buffer
      ..writeln('\nclass ${className}Adapter extends TypeAdapter<$className> {')
      ..writeln('  @override')
      ..writeln(
        '  final int typeId = ${modelNamesMap.toList().indexOf(className)};',
      )
      ..writeln()
      ..writeln('  @override')
      ..writeln('  $className read(BinaryReader reader) {')
      ..writeln('    final numOfFields = reader.readByte();')
      ..writeln('    final fields = <int, dynamic>{')
      ..writeln(
        '      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),',
      )
      ..writeln('    };')
      ..writeln('    return $className(');
    var fieldIndex = 0;
    fields.forEach((fieldName, fieldSchema) {
      buffer.writeln(
        '      $fieldName: fields[$fieldIndex] as ${getFieldType(fieldSchema as Map<String, dynamic>)},',
      );
      fieldIndex++;
    });
    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  void write(BinaryWriter writer, $className obj) {')
      ..writeln('    writer')
      ..writeln('      ..writeByte(${fields.length})');
    fieldIndex = 0;
    fields.forEach((fieldName, fieldSchema) {
      buffer
        ..writeln('      ..writeByte($fieldIndex)')
        ..writeln('      ..write(obj.$fieldName)');
      fieldIndex++;
    });
    buffer
      ..writeln('    ;')
      ..writeln('  }')
      ..writeln('}');
  }

  void generateResultClass(StringBuffer buffer) {
    buffer.writeln(r'''
class Result<T, E> {
  final T? data;
  final E? errorData;
  final bool isSuccess;
  final bool isFromCache;
  final bool isOfflineQueued;

  const Result({
    this.data,
    this.errorData,
    required this.isSuccess,
    this.isFromCache = false,
    this.isOfflineQueued = false,
  });

  bool get isFailure => !isSuccess;

  Result<T, E> copyWith({
    T? data,
    E? errorData,
    bool? isSuccess,
    bool? isFromCache,
    bool? isOfflineQueued,
  }) {
    return Result<T, E>(
      data: data ?? this.data,
      errorData: errorData ?? this.errorData,
      isSuccess: isSuccess ?? this.isSuccess,
      isFromCache: isFromCache ?? this.isFromCache,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
    );
  }

  @override
  String toString() {
    return 'Result{data: $data, errorData: $errorData, isSuccess: $isSuccess, isFromCache: $isFromCache, isOfflineQueued: $isOfflineQueued}';
  }

  factory Result.success(T data, {bool isFromCache = false}) => Result<T, E>(
        data: data,
        isSuccess: true,
        isFromCache: isFromCache,
      );

  factory Result.failure(E errorData, {bool isOfflineQueued = false}) => Result<T, E>(
        errorData: errorData,
        isSuccess: false,
        isOfflineQueued: isOfflineQueued,
      );

  factory Result.offlineQueued() => Result<T, E>(
        isSuccess: false,
        isOfflineQueued: true,
      );

  bool get isSuccessFromNetwork => isSuccess && !isFromCache;
  bool get isSuccessFromCache => isSuccess && isFromCache;

  R when<R>({
    required R Function(T data) success,
    required R Function(E errorData) failure,
    R Function()? offlineQueued,
  }) {
    if (isSuccess) {
      return success(data as T);
    } else if (isOfflineQueued) {
      return offlineQueued?.call() ?? failure(errorData as E);
    } else {
      return failure(errorData as E);
    }
  }
}
''');
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
        '          return ${HelperMehods.getReturnType(throwErrorType, returnType)}(errorData: result, isSuccess: true);',
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
        '          return ${HelperMehods.getReturnType(throwErrorType, returnType)}(data: result, isSuccess: true);',
      );
    } else {
      buffer
        ..writeln('        case 200:')
        ..writeln(
          '          return ${HelperMehods.getReturnType(throwErrorType, returnType)}(isSuccess: true);',
        );
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
        '  Future<http.Response> get(String url, {Map<String, String>? headers}) async {',
      )
      ..writeln(
        r"    final response = await http.get(Uri.parse('$baseUrl$url'), headers: {...this.headers, ...?headers});",
      )
      ..writeln('    if (response.statusCode == 401) {')
      ..writeln('      final result = await refreshToken();')
      ..writeln('      if (result) {')
      ..writeln(
        r"        final response = await http.get(Uri.parse('$baseUrl$url'), headers: {...this.headers, ...?headers});",
      )
      ..writeln('        return response;')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    return response;')
      ..writeln('  }')
      ..writeln()
      ..writeln('  Future<bool> refreshToken() async {')
      ..writeln(
        '    final refreshToken = await handelJsonToken.getRefreshToken;',
      )
      ..writeln('    if (refreshToken != null) {')
      ..writeln(
        '      final request = RefreshRequest(refreshToken: refreshToken);',
      )
      ..writeln('      final response = await http.post(')
      ..writeln(r"        Uri.parse('$baseUrl/refresh'),")
      ..writeln("        headers: {'Content-Type': 'application/json'},")
      ..writeln('        body: request.toJson(),')
      ..writeln('      );')
      ..writeln('      if (response.statusCode == 200) {')
      ..writeln(
        '        final result = AccessTokenResponse.fromJson(response.body);',
      )
      ..writeln(
        '        await handelJsonToken.setJsonToken(result.accessToken);',
      )
      ..writeln(
        '        await handelJsonToken.setRefreshToken(result.refreshToken);',
      )
      ..writeln(
        r"        headers['Authorization'] = 'Bearer ${result.accessToken}';",
      )
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

extension SetExtension<T> on Set<T> {
  int indexOf(T element) => toList().indexOf(element);
}
