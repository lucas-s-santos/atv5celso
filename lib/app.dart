import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/colors.dart';
import 'providers/delivery_provider.dart';
import 'screens/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeliveryProvider(),
      child: MaterialApp(
        title: 'Entregas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: AppColors.surface,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
