import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class UnifiedNewFeedService extends Service {
  // Topics decrements instantly client-side (plugin-consumed). Replies
  // only ever changes via setCounts, since it's driven by Discourse's
  // own read tracking, not by this plugin.
  @tracked topicsCount = null;
  @tracked repliesCount = null;

  // Set by the homepage override before transitioning here, so model()
  // can reuse an already-fetched payload for the matching tab.
  pendingFeedResult = null;

  // Combined total, used for the single "Feed (N)" nav bar item.
  get count() {
    return (this.topicsCount || 0) + (this.repliesCount || 0);
  }

  setCounts({ topics, replies }) {
    this.topicsCount = Number.isFinite(Number(topics)) ? Number(topics) : null;
    this.repliesCount = Number.isFinite(Number(replies)) ? Number(replies) : null;
  }

  decrementTopics(amount) {
    if (this.topicsCount === null) {
      return;
    }
    this.topicsCount = Math.max(0, this.topicsCount - amount);
  }

  stashFeedResult(pending) {
    this.pendingFeedResult = pending;
  }

  takePendingFeedResult(tab) {
    const pending = this.pendingFeedResult;
    this.pendingFeedResult = null;
    return pending && pending.tab === tab ? pending.result : null;
  }
}
