class HelperMehods {
  static String mapSwaggerTypeToDart(String? type) {
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

  static String mapSwaggerTypeToDartConstantValue(String? type) {
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

  static String getReturnType(String errorType, String returnType) {
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

  static bool isFieldTypeNull(Map<String, dynamic> fieldSchema) {
    late bool isNull;
    final fieldType = mapSwaggerTypeToDart(fieldSchema['type'] as String?);
    if (fieldType == 'int') {
      isNull = fieldSchema['format'] != 'int64';
    } else if (fieldType == 'dynamic') {
      isNull = false;
    } else {
      isNull = fieldSchema['nullable'] == true;
    }
    return isNull;
  }

  static String handelParameterSettingAndPathBuilding(
    List<dynamic>? parameters,
    List<String> queryParameters,
    List<String> buildQueryString,
    String path,
  ) {
    if (parameters != null) {
      for (var i = 0; i < parameters.length; i++) {
        final parameter = parameters[i] as Map<String, dynamic>;
        if (parameter['in'] == 'path') {
          final type = HelperMehods.mapSwaggerTypeToDart(
              parameter['schema']['type'] as String);
          final name = parameter['name'];
          queryParameters.add('required $type $name');
          continue;
        }
        if (parameter['in'] == 'query') {
          final type = HelperMehods.mapSwaggerTypeToDart(
              parameter['schema']['type'] as String);
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
}

extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);

  String get camelCase => replaceAllMapped(
        RegExp(r'_(\w)'),
        (match) => match.group(1)!.toUpperCase(),
      );
  String snakeCase() => replaceAllMapped(
        RegExp('[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      ).substring(1);
  //first letter lowercase
  String firstLetterLowerCase() => substring(0, 1).toLowerCase() + substring(1);
}

class HandelJsonToken {
  String? get getRefreshToken => null;

  setJsonToken(String accessToken) {}

  setRefreshToken(String refreshToken) {}
}
