import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { emptyRedirectRouteName } from "../lib/unified-new-feed-empty-redirect";

const ROUTE_NAME = "unified-new-feed";

// Consumption tracking lives in unified-new-feed-list.gjs. This
// initializer only handles the top nav "Feed (N)" item and redirecting
// eligible users into /feed from the homepage.
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

  // "feed" isn't a top_menu filter, so it needs addNavigationBarItem to
  // render; `name` still matches the route's @filterType for highlighting.
  api.addNavigationBarItem({
    name: "feed",
    title: i18n("discourse_unified_new_feed.navigation_label"),
    href: "/feed",
    before: siteSettings.top_menu.split("|")[0],
    // Hidden when both tabs are empty, since /feed would just redirect away.
    customFilter: () => (feedState.count || 0) > 0,
    // Getter (not a plain value) so it stays live across buildList() calls.
    get count() {
      return feedState.count || 0;
    },
  });

  // Redirect before anything renders, so there's no homepage flash.
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
          // Fetched above for tab=topic, so the route fetches its own.
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
