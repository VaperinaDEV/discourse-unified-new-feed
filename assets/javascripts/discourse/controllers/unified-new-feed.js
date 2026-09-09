import Controller from "@ember/controller";

export default class UnifiedNewFeedController extends Controller {
  queryParams = ["tab"];
  tab = "topic";
}
