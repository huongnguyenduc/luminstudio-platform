import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/cubit/shell_cubit.dart';
import 'package:lumin_studio_mobile/features/shell/presentation/shell_page.dart';

class LuminStudioApp extends StatelessWidget {
  const LuminStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShellCubit(),
      child: MaterialApp(
        title: 'Lumin Studio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF33665B),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const CustomerShellPage(),
      ),
    );
  }
}
