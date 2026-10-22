import 'package:flutter/material.dart';

import '../app_tabs.dart';
import '../core/config.dart';
import '../core/native.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../widgets/forms.dart';
import '../widgets/shell.dart';
import 'account_screens.dart';

/// The Account tab: who is signed in, their orders and wishlist, help, and
/// the pages the website keeps in its menu and footer (blog, stores,
/// partner, careers, policies).
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;

    void open(Widget screen) => AppRouter.push(context, screen);
    void link(String href) => AppRouter.open(context, href);

    return DFScaffold(
      title: 'Account',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // who
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(color: DF.line),
            ),
            child: user == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome to Doctor Fresh', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: DF.ink900)),
                      const SizedBox(height: 4),
                      const Text('Sign in to track your orders and service requests.',
                          style: TextStyle(fontSize: 13.5, color: DF.ink400, height: 1.4)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => open(const AuthScreen()),
                              style: FilledButton.styleFrom(
                                backgroundColor: DF.primary600,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => open(const AuthScreen(register: true)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DF.primary700,
                                side: const BorderSide(color: DF.primary300),
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: DF.primary50,
                        child: Text(user.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DF.primary700)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name.isEmpty ? 'Doctor Fresh customer' : user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DF.ink900)),
                            const SizedBox(height: 2),
                            Text('+91 ${user.mobile}', style: const TextStyle(fontSize: 13.5, color: DF.ink400)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        onPressed: () => open(const ProfileScreen(initialTab: 3)),
                        icon: const Icon(Icons.edit_outlined, color: DF.primary600),
                      ),
                    ],
                  ),
          ),

          // shortcuts
          const SizedBox(height: 14),
          Row(
            children: [
              _shortcut(Icons.inventory_2_outlined, 'Orders', () => open(const ProfileScreen(initialTab: 1))),
              const SizedBox(width: 10),
              _shortcut(Icons.favorite_border_rounded, 'Wishlist', () => open(const ProfileScreen(initialTab: 2))),
              const SizedBox(width: 10),
              _shortcut(Icons.build_outlined, 'Book service', () => AppTabs.current.value = AppTabs.services),
            ],
          ),

          _Group(title: 'My account', tiles: [
            _Tile(Icons.person_outline_rounded, 'Profile', () => open(const ProfileScreen())),
            _Tile(Icons.inventory_2_outlined, 'Order history', () => open(const ProfileScreen(initialTab: 1))),
            _Tile(Icons.favorite_border_rounded, 'Saved products', () => open(const ProfileScreen(initialTab: 2))),
            _Tile(Icons.location_on_outlined, 'Edit profile & address', () => open(const ProfileScreen(initialTab: 3))),
          ]),

          _Group(title: 'Help & support', tiles: [
            _Tile(Icons.call_outlined, 'Call ${Config.phone}', () => Native.call()),
            _Tile(Icons.chat_outlined, 'Chat on WhatsApp', () => Native.whatsapp()),
            _Tile(Icons.mail_outline_rounded, Config.email, () => Native.email()),
            _Tile(Icons.phone_callback_outlined, 'Request a call back', () => showCallbackSheet(context)),
            _Tile(Icons.assignment_outlined, 'Submit a service / purchase request', () => showRequestWizard(context)),
            _Tile(Icons.support_agent_outlined, 'Contact us', () => link('/contact')),
          ]),

          _Group(title: 'Explore', tiles: [
            _Tile(Icons.article_outlined, 'Blog & water guides', () => link('/blogs')),
            _Tile(Icons.storefront_outlined, 'Store locator', () => link('/store-locator')),
            _Tile(Icons.handshake_outlined, 'Become a partner', () => link('/partner')),
            _Tile(Icons.work_outline_rounded, 'Careers', () => link('/careers')),
            _Tile(Icons.settings_input_component_outlined, 'Spare parts', () => link('/spare-parts')),
          ]),

          if (state.legalPages.isNotEmpty)
            _Group(title: 'Policies', tiles: [
              for (final l in state.legalPages) _Tile(Icons.description_outlined, '${l['label']}', () => link('/legal/${l['slug']}')),
            ]),

          if (user != null) ...[
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.logout_rounded, color: DF.danger),
                title: const Text('Sign out', style: TextStyle(color: DF.danger, fontWeight: FontWeight.w600)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text('Your cart stays saved on this phone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                      ],
                    ),
                  );
                  if (ok == true) await state.signOut();
                },
              ),
            ),
          ],

          const SizedBox(height: 24),
          Center(child: Image.asset('assets/images/logo2-trimmed.png', height: 26)),
          const SizedBox(height: 6),
          Text('© ${DateTime.now().year} Doctor Fresh · Version 1.0.0',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: DF.ink300)),
        ],
      ),
    );
  }

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(icon, color: DF.primary600, size: 24),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DF.ink700)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Tile {
  const _Tile(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.tiles});
  final String title;
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: DF.ink400)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, t) in tiles.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 56, color: DF.line),
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: DF.primary50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(t.icon, size: 19, color: DF.primary700),
                    ),
                    title: Text(t.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: DF.ink900)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: DF.ink300),
                    onTap: t.onTap,
                    dense: true,
                    visualDensity: const VisualDensity(vertical: 1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
