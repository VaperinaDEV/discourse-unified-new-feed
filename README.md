# Discourse Unified New Feed

> 🚧 This plugin is under active development. Please do not use it in production yet.

Adds a per-user feed at `/feed`, fully decoupled from Discourse's own "Unified New" list. `/feed` has two independent tabs, no "All" - and the two tabs work in genuinely different ways:

## Topics

New topics, per Discourse's own **`consider_topics_new_when`** setting (via core's `new_results`) - this plugin never invents a parallel "is this new" rule.

- **State**: plugin-tracked. `UnifiedNewFeedItem` holds one row per user per pending (not-yet-consumed) topic.
- **Initial seed**: the first time a user's feed is built, `DiscourseUnifiedNewFeed::FeedSync` takes core's `new_results` as-is - no date bound of our own. `new_results` already resolves both levels of "what counts as new" itself - the site-wide default (`default_other_new_topic_duration_minutes`) and the user's own override ("Consider topics new when", `user_option.new_topic_duration_minutes`), including the "always"/"last visit" special cases - together with `new_since`. This plugin reads neither setting and computes no window of its own; a brand-new user naturally gets "topics created within their effective new-topic window" and an existing user naturally gets nothing they've already effectively seen.
- **Ongoing**: every later sync only looks at topics created since the last sync (a per-user watermark in `UnifiedNewFeedSync`), so it only ever adds genuinely new content.
- **Consumption**: viewport-based. A topic is marked consumed once it has been visible past the configured threshold for the configured dwell time. It **stays visible in the current list** when that happens (no DOM/model removal, no scroll jump) - it simply won't be there the next time the feed loads, since its row is deleted server-side. Once consumed, a topic never comes back on its own.

## Replies

Topics with unread posts, per Discourse's own **read/unread tracking** (via core's `unread_results`) - again, no parallel definition.

- **State**: none. There is no table, no sync, no consumed flag for this tab at all.
- **Membership**: purely live. A topic is in the Replies feed because Discourse itself currently considers it unread for this user - full stop.
- **Leaving the feed**: purely live. The moment Discourse's own tracking says there's nothing unread left in that topic (the user read it - from this feed, from `/unread`, from a notification, anywhere), it drops out. The plugin never marks a topic read and never fakes a "consumed" state for it.
- **Reappearing**: a topic the user has already read (and that dropped out of Replies) can reappear if a new reply arrives, exactly like core's own Unread list - there's no plugin-side history to block it, because there's no plugin-side history at all for this tab.

## Tabs UI

The Topics/Replies switcher is a small custom component (`unified-new-feed-tabs.gjs`), not core's own unified-new subset switcher - `/new`'s own Topics/Replies/All pills come from core's `Navigation` component when `filterType="new"`, and reusing that directly would also pull in its "dismiss new"/"dismiss read" buttons, which write to Discourse's own read/dismissed state rather than this plugin's queue - exactly the coupling this feed is meant to avoid. Instead, the custom tabs sit in the same layout slot (above the list-controls bar, same as core's subset pills) and are styled with Discourse's own nav-pill tokens (`--d-nav-pill-border-radius`, the `--space-*` scale, `--tertiary`/`--primary-low`) so they match the site's look without depending on any specific core markup.

## Empty states

- If **one** tab has nothing left, `/feed` stays put and that tab shows its own inline empty message. The user can still switch to the other tab.
- Only when **both** tabs are empty does `/feed` (and the homepage override) redirect to the configured empty-redirect route.

## Navigation & homepage

For enabled groups, a "Feed" item is added to the top navigation (via `addNavigationBarItem`) showing the combined Topics+Replies count, and `/` sends eligible users straight into whichever tab has items (preferring Topics). This happens inside `discovery.index`'s own `beforeModel`, so there's no homepage flash before the redirect.

Note: because Replies has no plugin-tracked consumption, its live counter (the tab label, the nav item) only updates on the next fetch (switching tabs, reloading, revisiting the homepage) - not instantly while reading a topic, since that would require guessing at Discourse's internal read-marking rather than just asking it fresh each time.

## Settings

- Enabled
- Dwell time (Topics tab only)
- Visibility threshold (Topics tab only)
- Batch size (safety cap on the consume endpoint; also the Topics tab's viewport-flush batch size)
- Enabled groups
- Empty redirect
