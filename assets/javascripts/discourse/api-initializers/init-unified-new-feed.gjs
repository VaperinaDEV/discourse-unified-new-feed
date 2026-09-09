import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { emptyRedirectRouteName } from "../lib/unified-new-feed-empty-redirect";

const ROUTE_NAME = "unified-new-feed";

// Consumption (viewport tracking for Topics, click tracking for
// Replies) now lives in components/unified-new-feed-list.gjs, scoped
// to whichever tab is actually mounted. This initializer only owns
// the two things that exist outside the /feed page itself: the top
// nav "Feed (N)" item, and sending eligible users straight into /feed
// from the homepage.
function isEligibleUser(currentUser, siteSettings) {
  if (!siteSettings.unified_new_feed_enabled || !currentUser) {
    return false;
  }

  const configuredGroups = siteSettings.unified_new_feed_groups;
  const groupIds = (
    Array.isArray(configuredGroups)
      ? configuredGroups
      : String(configuredGroups || "").split("|")
  )
    .filter(Boolean)
    .map(Number);

  return (
    groupIds.length === 0 ||
    !!currentUser.groups?.some((group) => groupIds.includes(Number(group.id)))
  );
}

export default apiInitializer("0.7.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();

  if (!isEligibleUser(currentUser, siteSettings)) {
    return;
  }

  const feedState = api.container.lookup("service:unified-new-feed");

  // "feed" isn't a top_menu filter, so it needs the ExtraNavItem path
  // (addNavigationBarItem) to render; it still highlights correctly since
  // its `name` matches the route's `@filterType="feed"`.
  api.addNavigationBarItem({
    name: "feed",
    title: i18n("discourse_unified_new_feed.navigation_label"),
    href: "/feed",
    before: siteSettings.top_menu.split("|")[0],
    // Hidden when both tabs are empty, since /feed would just redirect
    // away anyway.
    customFilter: () => (feedState.count || 0) > 0,
    // No `displayName`: NavItem builds "Feed (N)" itself from
    // filters.feed.title(_with_count). `count` must be a getter so it
    // stays live across buildList() calls instead of freezing at boot.
    get count() {
      return feedState.count || 0;
    },
  });

  // Hook into discovery.index's beforeModel (before anything renders) so
  // eligible users land on /feed with no homepage flash.
  api.modifyClass("route:discovery.index", {
    pluginId: "discourse-unified-new-feed",

    async beforeModel(transition) {
      try {
        const result = await ajax("/feed.json?tab=topic");
        const topicsCount = result?.topic_list?.unconsumed_topics_count || 0;
        const repliesCount = result?.topic_list?.unconsumed_replies_count || 0;

        feedState.setCounts({ topics: topicsCount, replies: repliesCount });

        if (topicsCount > 0) {
          feedState.stashFeedResult({ tab: "topic", result });
          this.router.replaceWith(ROUTE_NAME, {
            queryParams: { tab: "topic" },
          });
          return;
        }

        if (repliesCount > 0) {
          // The payload above was fetched for tab=topic, so it can't be
          // reused for the replies tab - the route will fetch its own.
          this.router.replaceWith(ROUTE_NAME, {
            queryParams: { tab: "reply" },
          });
          return;
        }

        const emptyRoute = emptyRedirectRouteName(siteSettings);
        if (emptyRoute) {
          this.router.replaceWith(emptyRoute);
          return;
        }
      } catch (_error) {
        // Fall back to the normal homepage on error.
      }

      return this._super(transition);
    },
  });
});
