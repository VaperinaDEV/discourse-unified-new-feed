import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class UnifiedNewFeedService extends Service {
  @tracked count = null;

  // Set by the homepage override before it transitions here, so model()
  // can reuse the already-fetched payload instead of requesting it again.
  pendingFeedResult = null;

  setCount(value) {
    this.count = Number.isFinite(Number(value)) ? Number(value) : null;
  }

  decrement(amount) {
    if (this.count === null) {
      return;
    }

    this.count = Math.max(0, this.count - amount);
  }

  stashFeedResult(result) {
    this.pendingFeedResult = result;
  }

  takePendingFeedResult() {
    const result = this.pendingFeedResult;
    this.pendingFeedResult = null;
    return result;
  }
}
