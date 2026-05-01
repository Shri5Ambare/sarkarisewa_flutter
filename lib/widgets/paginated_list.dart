// lib/widgets/paginated_list.dart
//
// Cursor-based "infinite list" wrapper for Firestore-backed admin screens.
// Pass a `fetchPage` callback that takes the previous cursor and returns
// the next batch + new cursor. The widget handles the load-more UX, error
// recovery, pull-to-refresh, and the empty state.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'app_button.dart';
import 'empty_state.dart';

typedef FetchPage = Future<({List<Map<String, dynamic>> items, DocumentSnapshot? cursor})>
    Function({int pageSize, DocumentSnapshot? startAfter});

class PaginatedList extends StatefulWidget {
  final FetchPage fetchPage;
  final Widget Function(BuildContext, Map<String, dynamic> item, int index) itemBuilder;
  final int pageSize;
  final EdgeInsets padding;
  final String emptyTitle;
  final String? emptyMessage;
  final String emptyEmoji;

  const PaginatedList({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.pageSize = 25,
    this.padding = const EdgeInsets.all(16),
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyEmoji = '📭',
  });

  @override
  State<PaginatedList> createState() => _PaginatedListState();
}

class _PaginatedListState extends State<PaginatedList> {
  final List<Map<String, dynamic>> _items = [];
  DocumentSnapshot? _cursor;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _initialLoading = true;
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    try {
      final page = await widget.fetchPage(pageSize: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.items.length >= widget.pageSize;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.fetchPage(
        pageSize: widget.pageSize,
        startAfter: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.items.length >= widget.pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(onAction: _refresh);
    }
    if (_items.isEmpty) {
      return EmptyState(
        emoji: widget.emptyEmoji,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: widget.padding,
        itemCount: _items.length + (_hasMore || _loadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            // Footer: spinner while loading more, "Load more" button on
            // error or idle state. Keeps the user in control.
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2,
                      )
                    : AppButton(
                        label: _error != null ? 'Retry' : 'Load more',
                        onPressed: _loadMore,
                        style: AppButtonStyle.outline,
                        size: AppButtonSize.sm,
                      ),
              ),
            );
          }
          return widget.itemBuilder(ctx, _items[i], i);
        },
      ),
    );
  }
}
