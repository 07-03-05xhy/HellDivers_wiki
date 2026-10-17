import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/wiki_models.dart';
import 'data/wiki_repository.dart';
import 'data/wiki_repository_impl.dart';
import 'theme/hd_theme.dart';
import 'ui/pages/home_page.dart';

void main() {
  // wiki.gg 的图片 CDN 拦截 dart:io 默认 UA（Dart/x.x (dart:io) 一律 403），
  // 全局替换为应用 UA，让 CachedNetworkImage / flutter_cache_manager 都能取图。
  HttpOverrides.global = _WikiHttpOverrides();
  runApp(const HelldiversWikiApp());
}

/// 为所有 dart:io HttpClient（含 cached_network_image 内部）统一设置 UA。
class _WikiHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpClient client = super.createHttpClient(context);
    client.userAgent = kWikiUserAgent;
    return client;
  }
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
