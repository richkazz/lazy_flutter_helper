import 'dart:io';
import 'package:lazy_flutter_helper/generator/src/generator.dart';
import 'package:lazy_flutter_helper/generator/src/swagger_parser.dart';

//dart compile exe bin/swagger_to_dart.dart
class SwaggerToDart {
  SwaggerToDart();
  Future<SwaggerToDartResult> start({
    required String swaggerUrl,
    required String filePathToGenerate,
  }) async {
    final parser = SwaggerParser(swaggerUrl);
    final swaggerData = await parser.parseSwaggerJson();

    //String filePathToGenerate = 'C:\\Projects\\dart\\swagger_to_dart\\lib';
    //final filePathToGenerate = await getDirectoryPathToGenerateFiles();
    await Directory('$filePathToGenerate\\generated').create();
    await Directory('$filePathToGenerate\\generated\\models').create();
    await Directory('$filePathToGenerate\\generated\\enums').create();

    final result =
        DartGenerator(swaggerData, '$filePathToGenerate\\generated').generate();
    return result;
  }
}

class SwaggerToDartResult {
  const SwaggerToDartResult(
      {required this.modelsNames,
      required this.enumNames,
      required this.methodNames,
      required this.enumNamesAndDefinitions,
      required this.modelNamesAndDefinitionsMap,
      required this.methodNamesAndSignatures});
  final List<String> modelsNames;
  final List<String> enumNames;
  final List<String> methodNames;
  final Map<String, String> methodNamesAndSignatures;
  final Map<String, String> enumNamesAndDefinitions;
  final Map<String, String> modelNamesAndDefinitionsMap;
}
