part of 'app_cubit.dart';

enum AppStateEnum {
  initial,
  generating,
  generated,
  error;

  bool get isInitial => this == AppStateEnum.initial;
  bool get isGenerating => this == AppStateEnum.generating;
  bool get isGenerated => this == AppStateEnum.generated;
  bool get isError => this == AppStateEnum.error;
}

class AppState extends Equatable {
  const AppState({
    this.appStateEnum = AppStateEnum.initial,
    this.swaggerToDartResult = const SwaggerToDartResult(
      modelsNames: [],
      enumNames: [],
      methodNames: [],
      methodNamesAndSignatures: {},
      enumNamesAndDefinitions: {},
      modelNamesAndDefinitionsMap: {},
    ),
  });
  final AppStateEnum appStateEnum;
  final SwaggerToDartResult swaggerToDartResult;
  @override
  List<Object> get props => [appStateEnum, swaggerToDartResult];

  AppState copyWith({
    AppStateEnum? appStateEnum,
    SwaggerToDartResult? swaggerToDartResult,
  }) {
    return AppState(
      appStateEnum: appStateEnum ?? this.appStateEnum,
      swaggerToDartResult: swaggerToDartResult ?? this.swaggerToDartResult,
    );
  }
}
