import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lazy_flutter_helper/bloc_generator/bloc_generator.dart';
import 'package:lazy_flutter_helper/generator/swagger_to_dart.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit({
    required SwaggerToDart swaggerToDart,
    required BlocGenerator blocGenerator,
  })  : _swaggerToDart = swaggerToDart,
        _blocGenerator = blocGenerator,
        super(const AppState());
  late final SwaggerToDart _swaggerToDart;
  late final BlocGenerator _blocGenerator;
  String swaggerUrl = '';
  String filePathToGenerate = '';
  bool isValid = false;
  String cubitName = '';
  final List<String> selectedModelsNames = [];
  final List<String> selectedEnumNames = [];
  final List<String> selectedMethodNames = [];
  final Map<String, String> selectedMethodNamesAndSignatures = {};

  Future<void> generate() async {
    if (swaggerUrl.isEmpty || filePathToGenerate.isEmpty) {
      return;
    }
    emit(state.copyWith(appStateEnum: AppStateEnum.generating));
    try {
      final result = await _swaggerToDart.start(
        swaggerUrl: swaggerUrl,
        filePathToGenerate: filePathToGenerate,
      );
      emit(state.copyWith(
          appStateEnum: AppStateEnum.generated, swaggerToDartResult: result));
    } catch (e) {
      emit(state.copyWith(appStateEnum: AppStateEnum.error));
    }
    emit(state.copyWith(appStateEnum: AppStateEnum.initial));
  }

  Future<void> generateCubit(
      String filePathToGenerate, String cubitName) async {
    if (filePathToGenerate.isEmpty || cubitName.isEmpty) {
      return;
    }
    emit(state.copyWith(appStateEnum: AppStateEnum.generating));
    try {
      await _blocGenerator.generate(
        filePathToGenerate: filePathToGenerate,
        modelsNames: selectedModelsNames,
        enumNames: selectedEnumNames,
        methodNames: selectedMethodNames,
        methodNamesAndSignatures: selectedMethodNamesAndSignatures,
        cubitName: cubitName,
      );
      emit(state.copyWith(appStateEnum: AppStateEnum.generated));
    } catch (e) {
      emit(state.copyWith(appStateEnum: AppStateEnum.error));
    }
    emit(state.copyWith(appStateEnum: AppStateEnum.initial));
  }
}
