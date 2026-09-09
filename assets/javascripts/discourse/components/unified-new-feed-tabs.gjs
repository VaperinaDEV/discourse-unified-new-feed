import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import eq from "truth-helpers/helpers/eq";
import { i18n } from "discourse-i18n";

// Reads live counts from the service, not from route @args, so labels
// tick down in place as items get consumed.
//
// Markup/classes mirror core's topic-list/new-list-header-controls
// (the Topics/Replies toggle on /new) so this reuses core's own CSS
// and sits in the same spot (see templates/unified-new-feed.gjs).
export default class UnifiedNewFeedTabs extends Component {
  @service unifiedNewFeed;
  @service router;

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

  @action
  changeTab(tab) {
    if (tab === this.args.tab) {
      return;
    }

    this.router.transitionTo("unified-new-feed", { queryParams: { tab } });
  }

  <template>
    <div class="topic-replies-toggle-wrapper unified-new-feed-tabs">
      <button
        type="button"
        class="topics-replies-toggle --topics
          {{if (eq @tab "topic") "active"}}"
        {{on "click" (fn this.changeTab "topic")}}
      >
        {{this.topicsLabel}}
      </button>
      <button
        type="button"
        class="topics-replies-toggle --replies
          {{if (eq @tab "reply") "active"}}"
        {{on "click" (fn this.changeTab "reply")}}
      >
        {{this.repliesLabel}}
      </button>
    </div>
  </template>
}
