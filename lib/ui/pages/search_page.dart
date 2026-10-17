import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';

/// 搜索页：输入即搜（400ms 防抖），命中摘要高亮。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<WikiPageSummary> _results = <WikiPageSummary>[];
  bool _loading = false;
  Object? _error;

  WikiRepository get _repo => context.read<WikiRepository>();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(query.trim());
    });
  }

  Future<void> _doSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = <WikiPageSummary>[];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<WikiPageSummary> results = await _repo.search(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: HdSearchBar(
              controller: _controller,
              autofocus: true,
              hintText: '输入关键词搜索…',
              onChanged: _onQueryChanged,
              onSubmitted: (String q) => _doSearch(q.trim()),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const HdLoadingView(message: '搜索中…');
    }
    if (_error != null) {
      return HdErrorView(
        message: '搜索失败：$_error',
        onRetry: () => _doSearch(_controller.text.trim()),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty ? '输入关键词开始搜索' : '未找到相关条目',
          style: const TextStyle(color: HdColors.dimGrey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final WikiPageSummary item = _results[index];
        return HdPanelCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => ArticlePage(title: item.title)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HdColors.helldiverYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.snippet.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                // snippet 中的 <span class="searchmatch"> 渲染为黄色高亮。
                Html(
                  data: item.snippet,
                  shrinkWrap: true,
                  style: <String, Style>{
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: HdColors.dimGrey,
                      fontSize: FontSize(12),
                      maxLines: 2,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                    '.searchmatch': Style(
                      color: HdColors.helldiverYellow,
                      fontWeight: FontWeight.bold,
                      backgroundColor: HdColors.helldiverYellow
                          .withValues(alpha: 0.15),
                    ),
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
