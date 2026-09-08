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

  async model() {
    // Reuse the payload the homepage override may have already fetched.
    const result =
      this.unifiedNewFeed.takePendingFeedResult() ||
      (await ajax("/feed.json"));

    const munged = TopicList.munge(result, this.store);
    const model = this.store.createRecord("topicList", munged);

    model.set("params", {});
    model.set("filter", "new");
    model.unconsumedCount = result.topic_list.unconsumed_count || 0;

    const routeModel = {
      list: model,
      category: null,
      tag: null,
      unconsumedCount: model.unconsumedCount,
    };

    this.unifiedNewFeed.setCount(routeModel.unconsumedCount);
    return routeModel;
  }

  afterModel(model) {
    if (model.unconsumedCount !== 0 || model.more_topics_url) {
      return;
    }

    const target = emptyRedirectRouteName(this.siteSettings);
    if (target) {
      return this.router.replaceWith(target);
    }
  }
}
