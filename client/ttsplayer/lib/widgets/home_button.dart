import 'package:flutter/material.dart';


/// AppBar action that pops the entire navigation stack back to the home screen.
///
/// Uses [Navigator.popUntil] so it works from any depth — folder → subfolder
/// → item detail — without needing to know how many levels deep the user is.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Home',
      onPressed: () =>
          Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }
}
