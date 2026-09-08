import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import UnifiedNewFeedList from "../components/unified-new-feed-list";

export default <template>
  <Layout @model={{@model}} @listClass="--topic-list">
    <:navigation>
      <Navigation @filterType="feed" @model={{@model.list}} />
    </:navigation>
    <:list>
      <UnifiedNewFeedList @model={{@model.list}} />
    </:list>
  </Layout>
</template>
