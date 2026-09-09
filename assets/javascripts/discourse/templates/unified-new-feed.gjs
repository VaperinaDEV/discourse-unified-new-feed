import eq from "truth-helpers/helpers/eq";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import UnifiedNewFeedList from "../components/unified-new-feed-list";
import UnifiedNewFeedTabs from "../components/unified-new-feed-tabs";

export default <template>
  <Layout @model={{@model}} @listClass="--topic-list">
    <:navigation>
      <Navigation @filterType="feed" @model={{@model.list}} />
    </:navigation>
    <:list>
      <UnifiedNewFeedTabs @tab={{@model.tab}} />

      {{! Two distinct branches so switching tabs always remounts
        UnifiedNewFeedList, letting it set up tracking once per mount. }}
      {{#if (eq @model.tab "reply")}}
        <UnifiedNewFeedList @model={{@model.list}} @tab="reply" />
      {{else}}
        <UnifiedNewFeedList @model={{@model.list}} @tab="topic" />
      {{/if}}
    </:list>
  </Layout>
</template>
