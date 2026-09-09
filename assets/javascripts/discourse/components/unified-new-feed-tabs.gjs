import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import eq from "truth-helpers/helpers/eq";
import { i18n } from "discourse-i18n";

// Reads live counts from the service (not from route @args) so the
// labels tick down in place as items get consumed, without needing
// the route model to refresh.
//
// Markup/classes intentionally mirror core's
// topic-list/new-list-header-controls(-wrapper) (used for the
// Topics/Replies toggle on /new) so this reuses core's own CSS instead
// of a bespoke style - same wrapper class, same button class, same
// "active" convention - which is also what places it in the same
// position in the list (see templates/unified-new-feed.gjs).
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
    <div class="topic-replies-toggle-wrapper unified-new-feed-tabs">
      <LinkTo
        @route="unified-new-feed"
        @query={{hash tab="topic"}}
        class="topics-replies-toggle --topics
          {{if (eq @tab "topic") "active"}}"
      >
        {{this.topicsLabel}}
      </LinkTo>
      <LinkTo
        @route="unified-new-feed"
        @query={{hash tab="reply"}}
        class="topics-replies-toggle --replies
          {{if (eq @tab "reply") "active"}}"
      >
        {{this.repliesLabel}}
      </LinkTo>
    </div>
  </template>
}
