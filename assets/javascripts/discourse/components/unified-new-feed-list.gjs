import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { action } from "@ember/object";
import { service } from "@ember/service";

import { ajax } from "discourse/lib/ajax";
import List from "discourse/components/topic-list/list";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

const ROW_SELECTOR = ".topic-list-item[data-topic-id]";
const FLUSH_INTERVAL = 2000;

// One mount per tab (parent forces a remount on tab switch, see
// templates/unified-new-feed.gjs). Topics tracks viewport dwell and
// marks rows consumed (removed server-side next load, not spliced
// here). Replies does no tracking of its own - it just relies on
// Discourse's normal read tracking.
export default class UnifiedNewFeedList extends Component {
  @service siteSettings;
  @service unifiedNewFeed;

  queuedTopicIds = new Set();
  markedConsumed = new Set();
  dwellTimers = new Map();
  flushTimer = null;
  observer = null;
  mutationObserver = null;
  flushing = false;
  pagehideHandler = null;

  get isTopicsTab() {
    return this.args.tab !== "reply";
  }

  get isEmpty() {
    return (this.args.model.topics?.length || 0) === 0 && !this.args.model.canLoadMore;
  }

  get emptyMessage() {
    return this.isTopicsTab
      ? i18n("discourse_unified_new_feed.empty.topics")
      : i18n("discourse_unified_new_feed.empty.replies");
  }

  @action
  loadMore() {
    return this.args.model.loadMore();
  }

  @action
  setup(element) {
    if (this.isTopicsTab) {
      this.connectViewportTracking(element);
    }
  }

  @action
  teardown() {
    this.disconnectViewportTracking();
  }

  // ----- Topics tab: viewport-based consumption -----

  connectViewportTracking(element) {
    this.visibilityThreshold = this.siteSettings.unified_new_feed_visibility / 100;
    this.dwellTime = this.siteSettings.unified_new_feed_dwell_ms;

    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { threshold: [0, this.visibilityThreshold] }
    );
    this.observeRows(element);

    this.mutationObserver = new MutationObserver(() => this.observeRows(element));
    this.mutationObserver.observe(element, { childList: true, subtree: true });

    this.flushTimer = setInterval(() => this.flush(), FLUSH_INTERVAL);

    this.pagehideHandler = () => this.flush();
    window.addEventListener("pagehide", this.pagehideHandler);
  }

  disconnectViewportTracking() {
    if (!this.observer) {
      return;
    }

    void this.flush();

    this.observer.disconnect();
    this.observer = null;

    this.mutationObserver?.disconnect();
    this.mutationObserver = null;

    for (const timer of this.dwellTimers.values()) {
      clearTimeout(timer);
    }
    this.dwellTimers.clear();

    clearInterval(this.flushTimer);
    this.flushTimer = null;

    if (this.pagehideHandler) {
      window.removeEventListener("pagehide", this.pagehideHandler);
      this.pagehideHandler = null;
    }
  }

  observeRows(root) {
    if (!this.observer) {
      return;
    }

    root.querySelectorAll(ROW_SELECTOR).forEach((row) => {
      if (!this.markedConsumed.has(row.dataset.topicId)) {
        this.observer.observe(row);
      }
    });
  }

  handleIntersection(entries) {
    for (const entry of entries) {
      const row = entry.target;
      const topicId = row?.dataset?.topicId;
      if (!topicId || this.markedConsumed.has(topicId)) {
        continue;
      }

      if (entry.isIntersecting && entry.intersectionRatio >= this.visibilityThreshold) {
        if (!this.dwellTimers.has(topicId)) {
          this.dwellTimers.set(
            topicId,
            setTimeout(() => {
              this.dwellTimers.delete(topicId);
              this.markTopicConsumed(row, topicId);
            }, this.dwellTime)
          );
        }
      } else {
        const timer = this.dwellTimers.get(topicId);
        if (timer) {
          clearTimeout(timer);
          this.dwellTimers.delete(topicId);
        }
      }
    }
  }

  // Queues for the server but leaves the row in place - nothing
  // shifts mid-scroll, it just won't reappear on the next load.
  markTopicConsumed(row, topicId) {
    if (this.markedConsumed.has(topicId)) {
      return;
    }

    this.markedConsumed.add(topicId);
    this.queuedTopicIds.add(topicId);
    this.observer?.unobserve(row);

    const batchSize = this.siteSettings.unified_new_feed_batch_size || 25;
    if (this.queuedTopicIds.size >= batchSize) {
      void this.flush();
    }
  }

  async flush() {
    if (this.flushing || this.queuedTopicIds.size === 0) {
      return;
    }

    this.flushing = true;
    const batchSize = this.siteSettings.unified_new_feed_batch_size || 25;
    const ids = Array.from(this.queuedTopicIds).slice(0, batchSize);
    ids.forEach((id) => this.queuedTopicIds.delete(id));

    try {
      const result = await ajax("/unified-new-feed/consume.json", {
        type: "POST",
        data: { topic_ids: ids },
      });

      const consumedCount = result?.topic_ids?.length || 0;
      this.unifiedNewFeed.decrementTopics(consumedCount);
    } catch (_error) {
      ids.forEach((id) => this.queuedTopicIds.add(id));
    } finally {
      this.flushing = false;
    }
  }

  <template>
    <div
      class="unified-new-feed-list"
      {{didInsert this.setup}}
      {{willDestroy this.teardown}}
    >
      {{#if this.isEmpty}}
        <div class="unified-new-feed-list__empty">
          <p>{{this.emptyMessage}}</p>
        </div>
      {{else}}
        <List
          @showPosters={{true}}
          @showTopicPostBadges={{true}}
          @topics={{@model.topics}}
          @discoveryList={{true}}
          @listContext="discovery"
        />

        {{#if @model.canLoadMore}}
          <DLoadMore @action={{this.loadMore}} />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
