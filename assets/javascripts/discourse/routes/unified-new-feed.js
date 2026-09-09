import Route from "@ember/routing/route";
import { service } from "@ember/service";

import { ajax } from "discourse/lib/ajax";
import TopicList from "discourse/models/topic-list";
import { emptyRedirectRouteName } from "../lib/unified-new-feed-empty-redirect";

export default class UnifiedNewFeedRoute extends Route {
  @service store;
  @service unifiedNewFeed;
  @service router;
  @service siteSettings;

  queryParams = {
    tab: { refreshModel: true },
  };

  async model(params) {
    const tab = params.tab === "reply" ? "reply" : "topic";

    const result =
      this.unifiedNewFeed.takePendingFeedResult(tab) ||
      (await ajax(`/feed.json?tab=${tab}`));

    const munged = TopicList.munge(result, this.store);
    const model = this.store.createRecord("topicList", munged);

    model.set("params", {});
    model.set("filter", "new");

    const topicsCount = result.topic_list.unconsumed_topics_count || 0;
    const repliesCount = result.topic_list.unconsumed_replies_count || 0;

    this.unifiedNewFeed.setCounts({ topics: topicsCount, replies: repliesCount });

    return {
      list: model,
      category: null,
      tag: null,
      tab,
      topicsCount,
      repliesCount,
    };
  }

  afterModel(model) {
    // Only bail out of /feed entirely when BOTH tabs are exhausted -
    // an empty current tab with content still waiting in the other
    // tab shows its own inline empty state instead (see the list
    // component), and the user can still switch tabs.
    if (model.topicsCount !== 0 || model.repliesCount !== 0) {
      return;
    }

    const target = emptyRedirectRouteName(this.siteSettings);
    if (target) {
      return this.router.replaceWith(target);
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("tab", model.tab);
  }
}
