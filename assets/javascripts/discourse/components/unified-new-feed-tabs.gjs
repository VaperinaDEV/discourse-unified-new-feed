import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import eq from "truth-helpers/helpers/eq";
import { i18n } from "discourse-i18n";

// Reads live counts from the service (not from route @args) so the
// labels tick down in place as items get consumed, without needing
// the route model to refresh.
export default class UnifiedNewFeedTabs extends Component {
  @service unifiedNewFeed;

  get topicsLabel() {
    return i18n("discourse_unified_new_feed.tabs.topics", {
      count: this.unifiedNewFeed.topicsCount || 0,
    });
  }

  get repliesLabel() {
    return i18n("discourse_unified_new_feed.tabs.replies", {
      count: this.unifiedNewFeed.repliesCount || 0,
    });
  }

  <template>
    <nav class="unified-new-feed-tabs">
      <LinkTo
        @route="unified-new-feed"
        @query={{hash tab="topic"}}
        class="unified-new-feed-tabs__tab {{if (eq @tab "topic") "active"}}"
      >
        {{this.topicsLabel}}
      </LinkTo>
      <LinkTo
        @route="unified-new-feed"
        @query={{hash tab="reply"}}
        class="unified-new-feed-tabs__tab {{if (eq @tab "reply") "active"}}"
      >
        {{this.repliesLabel}}
      </LinkTo>
    </nav>
  </template>
}
