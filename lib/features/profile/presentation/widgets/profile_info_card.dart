import 'package:flutter/material.dart';

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
