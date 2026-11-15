import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/mohajon_warm_theme.dart';
import '../../data/help_faq_catalog.dart';

/// Embedded in the help page's scroll view; no server or account is needed to
/// read help, including when the user is troubleshooting an offline session.
class HelpFaqSection extends StatefulWidget {
  const HelpFaqSection({super.key});

  @override
  State<HelpFaqSection> createState() => _HelpFaqSectionState();
}

class _HelpFaqSectionState extends State<HelpFaqSection> {
  final _search = TextEditingController();
  String? _topicId;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear({bool resetTopic = false}) {
    _search.clear();
    setState(() {
      _query = '';
      if (resetTopic) _topicId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = l10n.locale.languageCode;
    final groups = [
      for (final topic in helpFaqTopics)
        if (_topicId == null || topic.id == _topicId)
          (topic: topic, entries: filterHelpFaqs(topic, _query)),
    ].where((group) => group.entries.isNotEmpty).toList();
    final count = groups.fold<int>(
      0,
      (sum, group) => sum + group.entries.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('faqIntro'),
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('help-faq-search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: l10n.t('faqSearchHint'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.t('faqClearSearch'),
                    onPressed: _clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: MohajonWarm.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          key: const Key('help-faq-topics'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                key: const Key('help-faq-topic-all'),
                label: Text(l10n.t('faqAllTopics')),
                selected: _topicId == null,
                onSelected: (_) => setState(() => _topicId = null),
              ),
              for (final topic in helpFaqTopics) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  key: Key('help-faq-topic-${topic.id}'),
                  label: Text(topic.title(language)),
                  selected: _topicId == topic.id,
                  onSelected: (selected) =>
                      setState(() => _topicId = selected ? topic.id : null),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.tP('faqQuestionCount', {
            'count': NumberFormat.decimalPattern(language).format(count),
          }),
          key: const Key('help-faq-count'),
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (groups.isEmpty)
          Container(
            key: const Key('help-faq-empty'),
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MohajonWarm.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MohajonWarm.goldBorder),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  color: MohajonWarm.goldText,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(l10n.t('faqNoResults'), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _clear(resetTopic: true),
                  child: Text(l10n.t('faqResetFilters')),
                ),
              ],
            ),
          ),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
            child: Text(
              group.topic.title(language),
              style: const TextStyle(
                color: MohajonWarm.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            key: Key('help-faq-group-${group.topic.id}'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: MohajonWarm.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MohajonWarm.goldBorder),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < group.entries.length;
                    index++
                  ) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: MohajonWarm.goldBorder,
                      ),
                    ExpansionTile(
                      key: Key('help-faq-entry-${group.entries[index].id}'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      iconColor: MohajonWarm.goldText,
                      collapsedIconColor: MohajonWarm.goldText,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      title: Text(
                        group.entries[index].question(language),
                        style: const TextStyle(
                          color: MohajonWarm.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      children: [
                        Text(
                          group.entries[index].answer(language),
                          style: const TextStyle(
                            color: MohajonWarm.muted,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
