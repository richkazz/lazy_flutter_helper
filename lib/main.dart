import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lazy_flutter_helper/app/cubit/app_cubit.dart';
import 'package:lazy_flutter_helper/bloc_generator/bloc_generator.dart';
import 'package:lazy_flutter_helper/generator/swagger_to_dart.dart';
import 'package:lazy_flutter_helper/home/home.dart';
import 'package:lazy_flutter_helper/home/swagger_item.dart';
import 'package:lazy_flutter_helper/src/src.dart';
import 'package:lazy_flutter_helper/widgets/input_text_field.dart';
import 'package:responsive_framework/responsive_framework.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.light,
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: Stack(
          children: [
            child!,
          ],
        ),
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(
            start: 1921,
            end: double.infinity,
            name: '4K',
          ),
        ],
      ),
      home: const HomePage(),
      // home: Scaffold(
      //   body: Padding(
      //     padding: const EdgeInsets.all(8),
      //     child: App(
      //       swaggerToDart: SwaggerToDart(),
      //       blocGenerator: BlocGenerator(),
      //     ),
      //   ),
      // ),
    );
  }
}

class App extends StatelessWidget {
  const App({
    required this.swaggerToDart,
    required this.blocGenerator,
    required this.swaggerItem,
    super.key,
  });
  final SwaggerToDart swaggerToDart;
  final BlocGenerator blocGenerator;
  final SwaggerItem swaggerItem;
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AppCubit(
        swaggerToDart: swaggerToDart,
        blocGenerator: blocGenerator,
      )
        ..swaggerUrl = swaggerItem.swaggerJsonUrl
        ..filePathToGenerate = swaggerItem.filepathToGenerate,
      child: const AppView(),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({
    super.key,
  });

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 70,
                  child: ElevatedButton(
                    onPressed: () async {
                      await context.read<AppCubit>().generate();
                    },
                    child: const Text('Generate'),
                  ),
                ),
                const SizedBox(
                  width: AppSpacing.lg,
                ),
                BlocBuilder<AppCubit, AppState>(
                  buildWhen: (previous, current) =>
                      !current.appStateEnum.isInitial,
                  builder: (context, state) {
                    return Text(state.appStateEnum.name);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppInputTextField(
                        labelText: 'Enter the cubit name:',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter some text';
                          }
                          final regex = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
                          if (!regex.hasMatch(value)) {
                            return 'Please enter a valid cubit name';
                          }
                          context.read<AppCubit>().cubitName = value;
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await context.read<AppCubit>().generateCubit(
                              context.read<AppCubit>().filePathToGenerate,
                              context.read<AppCubit>().cubitName,
                            );
                      },
                      child: const Text('Generate Cubit'),
                    ),
                  ],
                ),
              ],
            ),
            BlocSelector<AppCubit, AppState, SwaggerToDartResult>(
              selector: (state) {
                return state.swaggerToDartResult;
              },
              builder: (context, swaggerToDartResult) {
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchWidget(
                          values: swaggerToDartResult.modelsNames,
                        ),
                      ),
                      const SizedBox(
                        width: AppSpacing.lg,
                      ),
                      Expanded(
                        child: SearchEnumWidget(
                          values: swaggerToDartResult.enumNames,
                        ),
                      ),
                      const SizedBox(
                        width: AppSpacing.lg,
                      ),
                      Expanded(
                          child: SearchMethodWidget(
                        values: swaggerToDartResult.methodNames,
                      )),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _copyToClipboard(String text, BuildContext context) async {
  await Clipboard.setData(
    ClipboardData(
      text: text,
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Copied to clipboard'),
    ),
  );
}

class SearchWidget extends StatefulWidget {
  const SearchWidget({required this.values, super.key});
  final List<String> values;

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  List<String> searchResults = [];
  late SwaggerToDartResult swaggerToDartResult;
  @override
  void initState() {
    searchResults = widget.values.toList();
    super.initState();
  }

  void onSearch(String query) {
    setState(() {
      searchResults = widget.values
          .where(
            (element) => element.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppCubit, AppState>(
      listener: (context, state) {
        swaggerToDartResult = state.swaggerToDartResult;
        setState(() {
          searchResults = state.swaggerToDartResult.modelsNames.toList();
        });
      },
      child: Column(
        children: [
          AppInputTextField(
            labelText: 'Search Model',
            onChanged: onSearch,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return ModelListItem(
                  modelName: searchResults[index],
                  swaggerToDartResult: swaggerToDartResult,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SearchMethodWidget extends StatefulWidget {
  const SearchMethodWidget({required this.values, super.key});
  final List<String> values;

  @override
  State<SearchMethodWidget> createState() => _SearchSearchMethodWidgetState();
}

class _SearchSearchMethodWidgetState extends State<SearchMethodWidget> {
  List<String> searchResults = [];
  late SwaggerToDartResult swaggerToDartResult;
  @override
  void initState() {
    searchResults = widget.values.toList();
    super.initState();
  }

  void onSearch(String query) {
    setState(() {
      searchResults = widget.values
          .where(
            (element) => element.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppCubit, AppState>(
      listener: (context, state) {
        swaggerToDartResult = state.swaggerToDartResult;
        setState(() {
          searchResults = state.swaggerToDartResult.methodNames.toList();
        });
      },
      child: Column(
        children: [
          AppInputTextField(
            labelText: 'Search Method',
            onChanged: onSearch,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return Tooltip(
                  textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Colors.white,
                      ),
                  message: swaggerToDartResult
                      .methodNamesAndSignatures[searchResults[index]],
                  child: ListTile(
                    trailing: Checkbox(
                      onChanged: (value) {},
                      value: false,
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToClipboard(
                        swaggerToDartResult
                            .methodNamesAndSignatures[searchResults[index]]!,
                        context,
                      ),
                    ),
                    title: Text(
                      searchResults[index],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SearchEnumWidget extends StatefulWidget {
  const SearchEnumWidget({required this.values, super.key});
  final List<String> values;

  @override
  State<SearchEnumWidget> createState() => _SearchSearchEnumWidgetState();
}

class _SearchSearchEnumWidgetState extends State<SearchEnumWidget> {
  List<String> searchResults = [];
  late SwaggerToDartResult swaggerToDartResult;
  @override
  void initState() {
    searchResults = widget.values.toList();
    super.initState();
  }

  void onSearch(String query) {
    setState(() {
      searchResults = widget.values
          .where(
            (element) => element.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppCubit, AppState>(
      listener: (context, state) {
        swaggerToDartResult = state.swaggerToDartResult;
        setState(() {
          searchResults = state.swaggerToDartResult.enumNames.toList();
        });
      },
      child: Column(
        children: [
          AppInputTextField(
            labelText: 'Search Enum',
            onChanged: onSearch,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  trailing: Checkbox(
                    onChanged: (value) {},
                    value: false,
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(
                      swaggerToDartResult
                          .enumNamesAndDefinitions[searchResults[index]]!,
                      context,
                    ),
                  ),
                  title: Text(
                    searchResults[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ModelListItem extends StatefulWidget {
  const ModelListItem({
    required this.modelName,
    required this.swaggerToDartResult,
    super.key,
  });
  final String modelName;
  final SwaggerToDartResult swaggerToDartResult;
  @override
  State<ModelListItem> createState() => _ModelListItemState();
}

class _ModelListItemState extends State<ModelListItem> {
  bool _isChecked = false;
  void _onTap(bool? value) {
    if (value != null && value) {
      context.read<AppCubit>().selectedModelsNames.add(widget.modelName);
    } else {
      context.read<AppCubit>().selectedModelsNames.remove(widget.modelName);
    }
    setState(() {
      _isChecked = !_isChecked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      trailing: Checkbox(
        onChanged: _onTap,
        value: _isChecked,
      ),
      leading: IconButton(
        icon: const Icon(Icons.copy),
        onPressed: () => _copyToClipboard(
            widget.swaggerToDartResult
                .modelNamesAndDefinitionsMap[widget.modelName]!,
            context),
      ),
      title: Text(widget.modelName),
    );
  }
}
