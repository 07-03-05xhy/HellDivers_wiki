import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';

/// 条目详情页：flutter_html 渲染正文，目录抽屉，收藏切换，内链拦截。
class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key, required this.title});

  final String title;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final GlobalKey _anchorKey = GlobalKey();

  WikiArticle? _article;
  Object? _error;
  bool _isFavorite = false;

  WikiRepository get _repo => context.read<WikiRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final WikiArticle article = await _repo.article(widget.title);
      if (!mounted) {
        return;
      }
      // 进入即记录浏览历史（fire-and-forget）。
      unawaited(_repo.recordVisit(article.pageId, article.title));
      final bool fav = await _repo.isFavorite(article.pageId);
      if (!mounted) {
        return;
      }
      setState(() {
        _article = article;
        _isFavorite = fav;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e);
    }
  }

  Future<void> _toggleFavorite() async {
    final WikiArticle? article = _article;
    if (article == null) {
      return;
    }
    if (_isFavorite) {
      await _repo.removeFavorite(article.pageId);
    } else {
      await _repo.addFavorite(article.pageId, article.title);
    }
    if (!mounted) {
      return;
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  /// 处理正文链接：站内条目跳应用内页面，外链交给系统浏览器。
  void _onLinkTap(String? url) {
    if (url == null || url.isEmpty) {
      return;
    }
    String? internalTitle;
    if (url.startsWith('./')) {
      internalTitle = url.substring(2);
    } else if (url.startsWith('/zh/wiki/')) {
      internalTitle = url.substring('/zh/wiki/'.length);
    } else if (url.startsWith('$kWikiSiteBase/wiki/')) {
      internalTitle = url.substring('$kWikiSiteBase/wiki/'.length);
    }
    if (internalTitle != null) {
      final int hashIndex = internalTitle.indexOf('#');
      if (hashIndex >= 0) {
        internalTitle = internalTitle.substring(0, hashIndex);
      }
      final String title =
          Uri.decodeComponent(internalTitle).replaceAll('_', ' ').trim();
      if (title.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => ArticlePage(title: title)),
        );
      }
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    }
  }

  /// 目录点击：滚动到对应锚点。
  void _scrollToSection(WikiSection section) {
    Navigator.of(context).pop(); // 关闭抽屉
    final BuildContext? anchorContext =
        AnchorKey.forId(_anchorKey, section.anchor)?.currentContext;
    if (anchorContext != null) {
      Scrollable.ensureVisible(
        anchorContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final WikiArticle? article = _article;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          article?.displayTitle ?? widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (article != null)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.star : Icons.star_outline,
                color: HdColors.helldiverYellow,
              ),
              tooltip: _isFavorite ? '取消收藏' : '收藏',
              onPressed: _toggleFavorite,
            ),
          if (article != null && article.sections.isNotEmpty)
            Builder(
              builder: (BuildContext context) => IconButton(
                icon: const Icon(Icons.format_list_bulleted),
                tooltip: '目录',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
        ],
      ),
      endDrawer: article == null ? null : _buildTocDrawer(article),
      body: _buildBody(article),
    );
  }

  Widget _buildTocDrawer(WikiArticle article) {
    return Drawer(
      backgroundColor: HdColors.panelGrey,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const HdSectionHeader(title: '目录'),
            for (final WikiSection section in article.sections)
              InkWell(
                onTap: () => _scrollToSection(section),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 8.0 + (section.level - 1).clamp(0, 4) * 14.0,
                    top: 10,
                    bottom: 10,
                  ),
                  child: Text(
                    section.line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: section.level <= 2
                          ? HdColors.textPrimary
                          : HdColors.dimGrey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(WikiArticle? article) {
    if (_error != null) {
      return HdErrorView(message: '条目加载失败：$_error', onRetry: _load);
    }
    if (article == null) {
      return const HdLoadingView();
    }
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Html(
          data: article.html,
          anchorKey: _anchorKey,
          onLinkTap: (String? url, _, __) => _onLinkTap(url),
          style: <String, Style>{
            'body': Style(
              color: HdColors.textPrimary,
              fontSize: FontSize(15),
              lineHeight: const LineHeight(1.6),
            ),
            'h1': _headingStyle(24),
            'h2': _headingStyle(20),
            'h3': _headingStyle(17),
            'h4': _headingStyle(15),
            'a': Style(
              color: HdColors.helldiverYellow,
              textDecoration: TextDecoration.none,
            ),
            'table': Style(
              backgroundColor: HdColors.panelGrey,
              border: Border.all(color: HdColors.lineGrey),
            ),
            'th': Style(
              backgroundColor: HdColors.voidBlack,
              color: HdColors.helldiverYellow,
              padding: HtmlPaddings.all(8),
              border: Border.all(color: HdColors.lineGrey),
            ),
            'td': Style(
              padding: HtmlPaddings.all(8),
              border: Border.all(color: HdColors.lineGrey),
            ),
            'code': Style(
              backgroundColor: HdColors.panelGrey,
              color: HdColors.helldiverYellow,
            ),
          },
          extensions: <HtmlExtension>[
            ImageExtension(builder: (ExtensionContext extensionContext) {
              String src = extensionContext.attributes['src'] ?? '';
              if (src.startsWith('//')) {
                src = 'https:$src';
              }
              if (src.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                      imageUrl: src,
                      httpHeaders: const <String, String>{
                        'User-Agent': kWikiUserAgent,
                      },
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        height: 120,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: HdColors.dimGrey,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Style _headingStyle(double size) {
    return Style(
      color: HdColors.helldiverYellow,
      fontSize: FontSize(size),
      fontWeight: FontWeight.bold,
      margin: Margins.only(top: 16, bottom: 8),
    );
  }
}
