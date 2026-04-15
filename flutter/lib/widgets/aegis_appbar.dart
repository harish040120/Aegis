import 'package:flutter/material.dart';

class AegisAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const AegisAppBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/main_logo.png',
            height: 28,
          ),
          SizedBox(width: 10),
          Text(title),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}