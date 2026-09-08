import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { emptyRedirectRouteName } from "../lib/unified-new-feed-empty-redirect";

const ROUTE_NAME = "unified-new-feed";
const ROW_SELECTOR = ".topic-list-item[data-topic-id]";
const FLUSH_INTERVAL = 2000;

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
    !!currentUser.visibleGroups?.some((group) =>
      groupIds.includes(Number(group.id))
    )
  );
}

export default apiInitializer("0.5.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();

  if (!isEligibleUser(currentUser, siteSettings)) {
    return;
  }

  const feedState = api.container.lookup("service:unified-new-feed");
  const router = api.container.lookup("service:router");
  const visibilityThreshold = siteSettings.unified_new_feed_visibility / 100;
  const dwellTime = siteSettings.unified_new_feed_dwell_ms;
  const batchSize = siteSettings.unified_new_feed_batch_size;

  // "feed" isn't a top_menu filter, so it needs the ExtraNavItem path
  // (addNavigationBarItem) to render; it still highlights correctly since
  // its `name` matches the route's `@filterType="feed"`.
  api.addNavigationBarItem({
    name: "feed",
    title: i18n("discourse_unified_new_feed.navigation_label"),
    href: "/feed",
    before: siteSettings.top_menu.split("|")[0],
    // Hidden when empty, since /feed would just redirect away anyway.
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
        const result = await ajax("/feed.json");
        const unconsumedCount = result?.topic_list?.unconsumed_count || 0;

        if (unconsumedCount > 0) {
          feedState.stashFeedResult(result);
          this.router.replaceWith(ROUTE_NAME);
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

  // Viewport tracking: mark topics consumed once actually seen.
  let observer;
  let mutationObserver;
  let flushTimer;
  let syncTimer;
  let active = false;
  let flushing = false;
  const queuedTopicIds = new Set();
  const seenInSession = new Set();
  const dwellTimers = new Map();

  function clearDwellTimer(row) {
    const topicId = row?.dataset?.topicId;
    if (!topicId) {
      return;
    }

    const timer = dwellTimers.get(topicId);
    if (timer) {
      clearTimeout(timer);
      dwellTimers.delete(topicId);
    }
  }

  function markConsumed(row) {
    const topicId = row?.dataset?.topicId;
    if (!topicId || seenInSession.has(topicId)) {
      return;
    }

    seenInSession.add(topicId);
    queuedTopicIds.add(topicId);

    if (queuedTopicIds.size >= batchSize) {
      void flush();
    }
  }

  function handleIntersection(entries) {
    for (const entry of entries) {
      const row = entry.target;
      const topicId = row?.dataset?.topicId;
      if (!topicId || seenInSession.has(topicId)) {
        continue;
      }

      if (
        entry.isIntersecting &&
        entry.intersectionRatio >= visibilityThreshold
      ) {
        if (!dwellTimers.has(topicId)) {
          dwellTimers.set(
            topicId,
            setTimeout(() => {
              dwellTimers.delete(topicId);
              markConsumed(row);
            }, dwellTime)
          );
        }
      } else {
        clearDwellTimer(row);
      }
    }
  }

  function observeRows(root = document) {
    if (!observer) {
      return;
    }

    root.querySelectorAll(ROW_SELECTOR).forEach((row) => {
      if (!seenInSession.has(row.dataset.topicId)) {
        observer.observe(row);
      }
    });
  }

  async function flush() {
    if (flushing || queuedTopicIds.size === 0) {
      return;
    }

    flushing = true;
    const ids = Array.from(queuedTopicIds).slice(0, batchSize);
    ids.forEach((id) => queuedTopicIds.delete(id));

    try {
      const result = await ajax("/unified-new-feed/consume.json", {
        type: "POST",
        data: { topic_ids: ids },
      });

      const consumedCount = result?.topic_ids?.length || 0;
      feedState.decrement(consumedCount);
    } catch (_error) {
      ids.forEach((id) => queuedTopicIds.add(id));
    } finally {
      flushing = false;
    }
  }

  function disconnect() {
    observer?.disconnect();
    mutationObserver?.disconnect();
    observer = null;
    mutationObserver = null;

    for (const timer of dwellTimers.values()) {
      clearTimeout(timer);
    }
    dwellTimers.clear();

    clearInterval(flushTimer);
    flushTimer = null;
    active = false;
  }

  function connect() {
    if (active) {
      return;
    }

    observer = new IntersectionObserver(handleIntersection, {
      threshold: [0, visibilityThreshold],
    });

    observeRows();

    const table = document.querySelector(".topic-list");
    if (table) {
      mutationObserver = new MutationObserver(() => observeRows(table));
      mutationObserver.observe(table, { childList: true, subtree: true });
    }

    flushTimer = setInterval(() => void flush(), FLUSH_INTERVAL);
    active = true;
  }

  function scheduleSync() {
    clearTimeout(syncTimer);
    syncTimer = setTimeout(() => {
      if (router.currentRoute?.name === ROUTE_NAME) {
        connect();
      } else {
        disconnect();
      }
    }, 0);
  }

  api.onPageChange(() => scheduleSync());
  scheduleSync();

  window.addEventListener("pagehide", () => void flush());
});
