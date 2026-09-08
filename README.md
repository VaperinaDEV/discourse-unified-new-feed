# Discourse Unified New Feed

> 🚧 This plugin is under active development. Please do not use it in production yet.

Adds a per-user feed at `/feed` which shows Unified New topics the user has not yet consumed. A topic is consumed after the configured percentage of its row remains visible for the configured dwell time.

Consumed state is separate from Discourse read/unread state. The plugin does not mark topics as read.

For enabled groups, a "Feed" item is added to the top navigation (via `addNavigationBarItem`, so it works regardless of `top_menu`), and `/` sends eligible users straight into the feed. This redirect happens inside `discovery.index`'s own `beforeModel` (the same hook core uses to route `/` to the configured homepage), so it never renders the normal homepage first - unlike an `onPageChange`-based redirect, there's no flash. When the feed is empty, both `/` and `/feed` itself redirect to the configured fallback route.

## Settings

- Enabled
- Dwell time
- Visibility threshold
- Batch size
- Enabled groups
- Empty redirect
