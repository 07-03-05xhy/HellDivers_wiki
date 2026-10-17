import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/wiki_repository.dart';
import 'data/wiki_repository_impl.dart';
import 'theme/hd_theme.dart';
import 'ui/pages/home_page.dart';

void main() {
  runApp(const HelldiversWikiApp());
}

class HelldiversWikiApp extends StatelessWidget {
  const HelldiversWikiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<WikiRepository>(
      create: (_) => WikiRepositoryImpl(),
      dispose: (_, WikiRepository repo) => repo.close(),
      child: MaterialApp(
        title: '绝地潜兵2 Wiki',
        debugShowCheckedModeBanner: false,
        theme: buildHdTheme(),
        home: const HomePage(),
      ),
    );
  }
}
