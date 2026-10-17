import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';

/// 浏览历史页：列表 + 清空按钮。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DateFormat _timeFormat = DateFormat('MM-dd HH:mm');

  List<HistoryEntry>? _entries;
  Object? _error;

  WikiRepository get _repo => context.read<WikiRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<HistoryEntry> entries = await _repo.history();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e);
    }
  }

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: HdColors.panelGrey,
        title: const Text('清空浏览历史'),
        content: const Text('确定要清空全部浏览记录吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空',
                style: TextStyle(color: HdColors.alertRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _repo.clearHistory();
    if (!mounted) {
      return;
    }
    setState(() => _entries = <HistoryEntry>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空历史',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return HdErrorView(message: '加载失败：$_error', onRetry: _load);
    }
    final List<HistoryEntry>? entries = _entries;
    if (entries == null) {
      return const HdLoadingView();
    }
    if (entries.isEmpty) {
      return const Center(
        child: Text('暂无浏览记录', style: TextStyle(color: HdColors.dimGrey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final HistoryEntry entry = entries[index];
        return HdPanelCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => ArticlePage(title: entry.title)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.history,
                  color: HdColors.helldiverYellow, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _timeFormat.format(entry.visitedAt),
                style:
                    const TextStyle(color: HdColors.dimGrey, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}
