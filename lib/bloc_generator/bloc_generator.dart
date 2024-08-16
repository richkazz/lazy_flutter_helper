// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:lazy_flutter_helper/common/helper_mehod.dart';
import 'package:lazy_flutter_helper/generator/src/generator_with_local_first.dart';

class BlocGenerator {
  Future<void> generate({
    required String filePathToGenerate,
    required List<String> modelsNames,
    required List<String> enumNames,
    required List<String> methodNames,
    required Map<String, String> methodNamesAndSignatures,
    required String cubitName,
  }) async {
    await Directory('$filePathToGenerate\\generated\\cubits').create();

    await generateCubit(
      filePathToGenerate: filePathToGenerate,
      modelsNames: modelsNames,
      enumNames: enumNames,
      methodNames: methodNames,
      methodNamesAndSignatures: methodNamesAndSignatures,
      cubitName: cubitName.capitalize(),
    );
    await generateCubitState(
      filePathToGenerate: filePathToGenerate,
      modelsNames: modelsNames,
      enumNames: enumNames,
      methodNames: methodNames,
      methodNamesAndSignatures: methodNamesAndSignatures,
      cubitName: cubitName.capitalize(),
    );
  }

  Future<void> generateCubit({
    required String filePathToGenerate,
    required List<String> modelsNames,
    required List<String> enumNames,
    required List<String> methodNames,
    required Map<String, String> methodNamesAndSignatures,
    required String cubitName,
  }) async {
    final buffer = StringBuffer()
      ..write("import 'package:bloc/bloc.dart';\n")
      ..write("import 'package:equatable/equatable.dart';\n")
      ..write(
        "import 'package:lazy_flutter_helper/generated/api_service.dart';\n",
      );
    if (modelsNames.isNotEmpty) {
      buffer.write(
        "import 'package:lazy_flutter_helper/generated/models/models.dart';\n",
      );
    }
    if (enumNames.isNotEmpty) {
      buffer.writeln(
        "import 'package:lazy_flutter_helper/generated/enums/enums.dart';\n\n",
      );
    }
    buffer
      ..writeln("part '${cubitName.snakeCase()}_state.dart';\n")
      ..writeln()
      /*
    class AttendanceCubitCubit extends Cubit<AttendanceCubitState> {
      AttendanceCubitCubit({
        required ApiService apiService,
      })  : _apiService = apiService,
            super(const AttendanceCubitState());
      final ApiService _apiService;
    }
    */
      ..write(
        'class ${cubitName.capitalize()}Cubit extends Cubit<${cubitName.capitalize()}State> {\n',
      )
      ..write('  ${cubitName.capitalize()}Cubit({\n')
      ..write(
        '    required ApiService apiService,\n',
      )
      ..write(
        '  }) : _apiService = apiService,\n',
      )
      ..write('    super(const ${cubitName.capitalize()}State());\n')
      ..write(
        '  final ApiService _apiService;\n',
      )
      ..write('}\n');

    await File(
      '$filePathToGenerate\\generated\\cubits\\${cubitName.snakeCase()}_cubit.dart',
    ).writeAsString(buffer.toString());
  }

  Future<void> generateCubitState({
    required String filePathToGenerate,
    required List<String> modelsNames,
    required List<String> enumNames,
    required List<String> methodNames,
    required Map<String, String> methodNamesAndSignatures,
    required String cubitName,
  }) async {
    final buffer = StringBuffer()
      ..write("part of '${cubitName.snakeCase()}_cubit.dart';\n\n")
      ..write('enum ${cubitName}StateEnum {\n')
      ..write('  initial,\n')
      ..write('  loading,\n')
      ..write('  success,\n')
      ..write('  error;\n')
      ..write(
        '\n  bool get isInitial => this == ${cubitName}StateEnum.initial;\n',
      )
      ..write(
        '  bool get isLoading => this == ${cubitName}StateEnum.loading;\n',
      )
      ..write(
        '  bool get isSuccess => this == ${cubitName}StateEnum.success;\n',
      )
      ..write('  bool get isError => this == ${cubitName}StateEnum.error;\n')
      ..write('}\n\n')
      ..write('class ${cubitName}State extends Equatable {\n')
      ..write('  const ${cubitName}State({\n')
      ..write(
        '    this.${cubitName.firstLetterLowerCase()}StateEnum = ${cubitName}StateEnum.initial,\n',
      );
    for (final element in modelsNames) {
      buffer.write(
        '    this.${element.firstLetterLowerCase()} = ${element.capitalize()}.empty,\n',
      );
    }

    buffer
      ..write('  });\n\n')
      ..write(
        '  final ${cubitName}StateEnum ${cubitName.firstLetterLowerCase()}StateEnum;\n',
      );

    for (final element in modelsNames) {
      buffer.write(
          '  final ${element.capitalize()} ${element.firstLetterLowerCase()};\n');
    }
    buffer
      ..write('  @override\n')
      ..write('  List<Object?> get props => [\n')
      ..write('    ${cubitName}StateEnum,\n');
    for (final element in modelsNames) {
      buffer.write('    ${element.firstLetterLowerCase()},\n');
    }
    buffer
      ..write('  ];\n')
      ..write('  ${cubitName}State copyWith({\n')
      ..write(
        '    ${cubitName}StateEnum? ${cubitName.firstLetterLowerCase()}StateEnum,\n',
      );
    for (final element in modelsNames) {
      buffer.write(
          '    ${element.capitalize()}? ${element.firstLetterLowerCase()},\n');
    }
    buffer
      ..write('  }) {\n')
      ..write('    return ${cubitName}State(\n')
      ..write(
        '      ${cubitName.firstLetterLowerCase()}StateEnum: ${cubitName.firstLetterLowerCase()}StateEnum ?? this.${cubitName.firstLetterLowerCase()}StateEnum,\n',
      );
    for (final element in modelsNames) {
      buffer.write(
        '      ${element.firstLetterLowerCase()}: ${element.firstLetterLowerCase()} ?? this.${element.firstLetterLowerCase()},\n',
      );
    }
    buffer
      ..write('    );\n')
      ..write('  }\n')
      ..write('}');

    File('$filePathToGenerate\\generated\\cubits\\${cubitName.snakeCase()}_state.dart')
        .writeAsStringSync(buffer.toString());
  }
}
