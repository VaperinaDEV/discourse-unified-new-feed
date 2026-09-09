import eq from "truth-helpers/helpers/eq";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import UnifiedNewFeedList from "../components/unified-new-feed-list";
import UnifiedNewFeedTabs from "../components/unified-new-feed-tabs";

export default <template>
  <Layout @model={{@model}} @listClass="--topic-list">
    <:navigation>
      <UnifiedNewFeedTabs @tab={{@model.tab}} />
      <Navigation @filterType="feed" @model={{@model.list}} />
    </:navigation>
    <:list>
      {{! Branches render two distinct blocks, so switching tabs always
        tears down and remounts UnifiedNewFeedList - which is what lets
        it safely set up viewport tracking (Topics) or click tracking
        (Replies) once per mount instead of reacting to @tab changing
        on a persisting instance. }}
      {{#if (eq @model.tab "reply")}}
        <UnifiedNewFeedList @model={{@model.list}} @tab="reply" />
      {{else}}
        <UnifiedNewFeedList @model={{@model.list}} @tab="topic" />
      {{/if}}
    </:list>
  </Layout>
</template>
