import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class UnifiedNewFeedService extends Service {
  // Kept fully separate per tab. Topics is plugin-consumed (viewport
  // dwell), so it can be decremented instantly client-side. Replies is
  // governed entirely by Discourse's own read tracking - this plugin
  // never marks anything read, so repliesCount only ever changes via a
  // fresh fetch (setCounts), never an explicit decrement.
  @tracked topicsCount = null;
  @tracked repliesCount = null;

  // Set by the homepage override before it transitions here, so
  // model() can reuse the already-fetched payload instead of
  // requesting it again. { tab, result } - only reused when the tab
  // matches what the route is about to render.
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
