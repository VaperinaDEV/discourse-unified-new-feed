import Component from "@glimmer/component";
import { action } from "@ember/object";
import List from "discourse/components/topic-list/list";
import DLoadMore from "discourse/ui-kit/d-load-more";

// Minimal by design: no subtabs/sort/bulk-select (those belong to the
// regular Unified New page). The "Feed (N)" count lives in the nav bar item.
export default class UnifiedNewFeedList extends Component {
  @action
  loadMore() {
    return this.args.model.loadMore();
  }

  <template>
    <div class="unified-new-feed-list">
      <List
        @showPosters={{true}}
        @showTopicPostBadges={{true}}
        @topics={{this.args.model.topics}}
        @discoveryList={{true}}
        @listContext="discovery"
      />

      {{#if this.args.model.canLoadMore}}
        <DLoadMore @action={{this.loadMore}} />
      {{/if}}
    </div>
  </template>
}
