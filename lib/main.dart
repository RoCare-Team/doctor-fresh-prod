import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tabs.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  await Store.instance.init();
  final state = AppState();
  runApp(DoctorFreshApp(state: state));
  state.init();
}

class DoctorFreshApp extends StatelessWidget {
  const DoctorFreshApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Doctor Fresh',
        debugShowCheckedModeBanner: false,
        theme: DF.theme(),
        home: const MainShell(),
      ),
    );
  }
}
