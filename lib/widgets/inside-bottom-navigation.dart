import 'package:flutter/material.dart';
import 'package:inside_chassidus/routes/primary-section-route.dart';

class InsideBottomNavigator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
          )
        ],
        currentIndex: 0,
        onTap: (_) =>
            Navigator.of(context).pushNamed(PrimarySectionsRoute.routeName));
  }
}
