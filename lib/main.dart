import 'package:flutter/material.dart';
import 'package:sailogger719/constant/colors.dart';
import 'package:sailogger719/screens/home_screen.dart';
import 'package:sailogger719/theme/theme_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CustomTheme.lightThemeData(context),
      darkTheme: CustomTheme.darkThemeData(),
      title: 'Sailogger App',
      home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: slapp_color.white_text,
              centerTitle: true,
              title: Image.asset(
                'assets/images/sailogger_logo.png',
                fit: BoxFit.fill,
                height: 23.0,
                width: 210.0,
              ),
            ),
            body: HomeScreen(),
          )),
    );
  }
}
