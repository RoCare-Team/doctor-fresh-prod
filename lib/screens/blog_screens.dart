import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/html_view.dart';
import '../widgets/net_image.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

/// The blog: the list (app/(shop)/blogs/page.jsx and blogs/[category]/page.jsx)
/// and one article (app/(shop)/blog/[id]/[slug]/page.jsx), with the cards and
/// comments of components/blogs/*.

/// BlogCard.jsx `CATEGORY_LABEL`.
const _categoryLabel = {
  'water-purifier': 'Water Purifier',
  'water-softener': 'Water Softener',
  'health': 'Health',
  'waterborne-disease': 'Waterborne Disease',
  'how-to': 'How To',
  'ro-plant': 'RO Plant',
  'ro-services': 'RO Services',
};

/// A white block on the grey canvas, 8px below the one before it.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.top = 8, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final Widget child;
  final double top;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: top),
        color: Colors.white,
        padding: padding,
        child: child,
      );
}

/// A small topic tag on an article, opening that topic's list.
class _TopicChip extends StatelessWidget {
  const _TopicChip(this.label, {this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DF.primary700)),
      ),
    );
  }
}

/// One article in a list (components/blogs/BlogCard.jsx): the picture on
/// the left, the topic, title and date on the right.
class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final cats = (post['categories'] as List? ?? const []).map((e) => '$e').toList();
    final badge = cats.isEmpty ? null : (_categoryLabel[cats.first] ?? cats.first);
    void open() => AppRouter.push(context, BlogPostScreen(id: toInt(post['id'])));

    return InkWell(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 104,
                height: 78,
                child: ColoredBox(color: DF.stage, child: NetImage(Config.url(str(post['image'])), fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Text(badge.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: DF.primary700)),
                    const SizedBox(height: 3),
                  ],
                  Text(str(post['title']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3, color: DF.ink900)),
                  const SizedBox(height: 6),
                  _Meta(post: post),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 28, left: 4),
              child: Icon(Icons.chevron_right, size: 20, color: DF.ink300),
            ),
          ],
        ),
      ),
    );
  }
}

/// "12 Mar 2025 · 4 min read".
class _Meta extends StatelessWidget {
  const _Meta({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${formatDate(post['date'])}  ·  ${toInt(post['readingMinutes'], 1)} min read',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12.5, color: DF.ink400),
    );
  }
}

/* ------------------------------------------------------------------ list */

/// "Doctor Fresh blog" — every article, or one topic's.
class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key, this.category});
  final String? category;

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  String? category;
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    category = widget.category;
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    final res = await Api.instance.get('/api/mobile/blog', query: {'category': category});
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        data = res.map;
      } else {
        error = res.error;
      }
    });
  }

  void _pick(String? slug) {
    if (slug == category) return;
    setState(() {
      category = slug;
      data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Blog',
      body:
          data == null ? LoadState(error: error, onRetry: _load) : RefreshIndicator(color: DF.primary600, onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final posts = mapsOf(data!['posts']);
    var categories = mapsOf(data!['categories']);
    if (categories.isEmpty) categories = AppScope.read(context).blogCategories;
    final current = categories.where((c) => str(c['slug']) == category).firstOrNull;
    final name = current == null ? (_categoryLabel[category] ?? category ?? '') : str(current['name']);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          color: Colors.white,
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            children: [
              DFChip('All', selected: category == null, onTap: () => _pick(null)),
              for (final c in categories) ...[
                const SizedBox(width: 8),
                DFChip(str(c['name']), selected: str(c['slug']) == category, onTap: () => _pick(str(c['slug']))),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text(
            category == null
                ? '${posts.length} ${posts.length == 1 ? 'article' : 'articles'}'
                : '${posts.length} ${posts.length == 1 ? 'article' : 'articles'} in $name',
            style: const TextStyle(fontSize: 13, color: DF.ink400),
          ),
        ),
        if (posts.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(color: DF.primary50, shape: BoxShape.circle),
                  child: const Icon(Icons.article_outlined, size: 40, color: DF.ink300),
                ),
                const SizedBox(height: 14),
                const Text('No articles in this topic yet',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                const SizedBox(height: 6),
                const Text('Pick another topic, or read everything we have written.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: DF.ink400)),
                const SizedBox(height: 16),
                PrimaryButton('Browse all articles', height: 44, onPressed: () => _pick(null)),
              ],
            ),
          )
        else
          for (final p in posts)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: _BlogCard(post: p),
            ),
        if (category == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Practical guides on water purification, RO servicing and water quality — written by the '
              'people who install and service these systems every day.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: DF.ink400),
            ),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------- one post */

/// One article: its text, the "Need help" box, the comments and three
/// related articles.
class BlogPostScreen extends StatelessWidget {
  const BlogPostScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return DFScaffold(
      title: 'Article',
      body: Loader(
        load: () => Api.instance.get('/api/mobile/blog', query: {'id': id}),
        builder: (context, data, reload) {
          final post = (data['post'] as Map? ?? const {}).cast<String, dynamic>();
          final related = mapsOf(data['related']);
          final cats = (post['categories'] as List? ?? const []).map((e) => '$e').toList();
          final known = AppScope.of(context).blogCategories;
          String label(String slug) => str(known.where((c) => str(c['slug']) == slug).firstOrNull?['name']).isNotEmpty
              ? str(known.firstWhere((c) => str(c['slug']) == slug)['name'])
              : (_categoryLabel[slug] ?? slug);
          final url = str(post['url']).isNotEmpty ? str(post['url']) : '/blog/$id/${str(post['slug'])}';
          final webUrl = str(post['webUrl']).isNotEmpty ? str(post['webUrl']) : Config.url(url);
          const meta = TextStyle(fontSize: 12.5, color: DF.ink400);

          return RefreshIndicator(
            color: DF.primary600,
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(color: DF.stage, child: NetImage(Config.url(str(post['image'])), fit: BoxFit.cover)),
                ),
                _Section(
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cats.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in cats) _TopicChip(label(c), onTap: () => AppRouter.push(context, BlogsScreen(category: c))),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(str(post['title']),
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.3, color: DF.ink900)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              [
                                if (str(post['author']).isNotEmpty) str(post['author']),
                                formatDate(post['date']),
                                '${toInt(post['readingMinutes'], 1)} min read',
                              ].join('  ·  '),
                              style: meta,
                            ),
                          ),
                          InkWell(
                            onTap: () => Native.share('${str(post['title'])}\n$webUrl', context: context),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.share_outlined, size: 15, color: DF.primary700),
                                SizedBox(width: 4),
                                Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DF.primary700)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Section(
                  child: HtmlView(str(post['contentHtml']), onLink: (href) => AppRouter.open(context, href)),
                ),
                _Section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Need help choosing or servicing a purifier?',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                      const SizedBox(height: 4),
                      const Text('Talk to a Doctor Fresh water expert or book a free water quality test at your home.',
                          style: TextStyle(fontSize: 13, height: 1.45, color: DF.ink400)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton('Call expert', height: 44, onPressed: () => Native.call('9311587716')),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlineButton('Book service',
                                height: 44, onPressed: () => AppRouter.open(context, '/water-purifier-service')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Comments(path: url),
                if (related.isNotEmpty)
                  _Section(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(10, 0, 10, 2),
                          child: Text('Related articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
                        ),
                        for (final (i, p) in related.take(3).indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 10, endIndent: 10),
                          _BlogCard(post: p),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* -------------------------------------------------------------- comments */

/// Comments and replies on an article (components/blogs/BlogComments.jsx).
class _Comments extends StatefulWidget {
  const _Comments({required this.path});
  final String path;

  @override
  State<_Comments> createState() => _CommentsState();
}

class _CommentsState extends State<_Comments> {
  List<Map<String, dynamic>> comments = [];
  String? replyTo;
  String status = 'idle'; // idle | sending | done | error
  String error = '';

  final name = TextEditingController();
  final email = TextEditingController();
  final comment = TextEditingController();
  final replyName = TextEditingController();
  final replyEmail = TextEditingController();
  final reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.instance.get('/api/comments', query: {'path': widget.path});
    if (!mounted) return;
    setState(() => comments = mapsOf(res.map['comments']));
  }

  Future<void> _post({String? commentId}) async {
    final isReply = commentId != null;
    final n = (isReply ? replyName : name).text.trim();
    final e = (isReply ? replyEmail : email).text.trim();
    final text = (isReply ? reply : comment).text.trim();
    if (n.isEmpty || e.isEmpty || text.isEmpty) {
      return setState(() {
        status = 'error';
        error = 'Please fill in every field.';
      });
    }
    setState(() {
      status = 'sending';
      error = '';
    });
    final res = await Api.instance.post('/api/comments', {
      'path': widget.path,
      'name': n,
      'email': e,
      if (isReply) 'reply': text else 'comment': text,
      'commentId': commentId,
    });
    if (!mounted) return;
    if (!res.ok) {
      return setState(() {
        status = 'error';
        error = res.map['error'] is String ? res.error : 'Could not post your comment.';
      });
    }
    setState(() {
      comments = mapsOf(res.map['comments']);
      status = 'done';
      replyTo = null;
      for (final c in [name, email, comment, replyName, replyEmail, reply]) {
        c.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sending = status == 'sending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(comments.isEmpty ? 'Comments' : 'Comments (${comments.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
              if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('No comments yet — be the first.', style: TextStyle(fontSize: 13, color: DF.ink400)),
                )
              else
                for (final (i, c) in comments.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: DF.primary50,
                              child: Text(
                                str(c['name']).isEmpty ? '?' : str(c['name']).substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DF.primary700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(str(c['name']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DF.ink900)),
                            ),
                            Text(formatDate(c['at']), style: const TextStyle(fontSize: 12.5, color: DF.ink400)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(str(c['body']), style: const TextStyle(fontSize: 14, height: 1.5, color: DF.ink500)),
                        if (mapsOf(c['replies']).isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                            decoration: BoxDecoration(color: DF.canvas, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final r in mapsOf(c['replies']))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(str(r['name']),
                                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DF.ink900)),
                                            Text(formatDate(r['at']), style: const TextStyle(fontSize: 12, color: DF.ink400)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(str(r['body']), style: const TextStyle(fontSize: 13.5, height: 1.5, color: DF.ink500)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => setState(() => replyTo = replyTo == str(c['id']) ? null : str(c['id'])),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(replyTo == str(c['id']) ? 'Cancel' : 'Reply',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DF.primary700)),
                          ),
                        ),
                        if (replyTo == str(c['id'])) ...[
                          const SizedBox(height: 8),
                          _input(replyName, 'Your name'),
                          _input(replyEmail, 'Your email', keyboard: TextInputType.emailAddress),
                          _input(reply, 'Write a reply', lines: 3),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PrimaryButton(sending ? 'Posting…' : 'Post reply',
                                height: 38, fontSize: 14, onPressed: sending ? null : () => _post(commentId: str(c['id']))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Leave a comment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DF.ink900)),
              const SizedBox(height: 2),
              const Text('Your email is not published.', style: TextStyle(fontSize: 12.5, color: DF.ink400)),
              const SizedBox(height: 12),
              DFField(label: 'Name', controller: name, required: true, hint: 'Your name'),
              DFField(label: 'Email', controller: email, required: true, hint: 'you@example.com', keyboard: TextInputType.emailAddress),
              DFField(label: 'Comment', controller: comment, required: true, hint: 'Share your thoughts', maxLines: 4),
              const SizedBox(height: 4),
              PrimaryButton(sending ? 'Posting…' : 'Post comment', height: 48, onPressed: sending ? null : () => _post()),
              if (status == 'done') ...[
                const SizedBox(height: 12),
                const SuccessNote('Thank you — your comment has been posted.'),
              ],
              if (status == 'error') ...[
                const SizedBox(height: 12),
                ErrorNote(error),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _input(TextEditingController c, String hint, {TextInputType? keyboard, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: lines,
          style: const TextStyle(fontSize: 15, color: DF.ink900),
          decoration: InputDecoration(hintText: hint),
        ),
      );
}
