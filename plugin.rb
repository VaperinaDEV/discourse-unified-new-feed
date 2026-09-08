# frozen_string_literal: true

# name: discourse-unified-new-feed
# about: Tracks Unified New topics as consumed when they are actually viewed in the viewport.
# version: 0.6.0
# authors: VaperinaDEV

enabled_site_setting :unified_new_feed_enabled

module ::DiscourseUnifiedNewFeed
  PLUGIN_NAME = "discourse-unified-new-feed"
end

after_initialize do
  require_relative "app/models/unified_new_feed_seen"
  require_relative "app/controllers/unified_new_feed_seen_controller"
  require_relative "app/controllers/unified_new_feed_controller"
  require_relative "lib/discourse_unified_new_feed/group_access"
  require_relative "lib/discourse_unified_new_feed/topic_query_extension"

  Discourse::Application.routes.append do
    get "/feed", to: "unified_new_feed#index", constraints: { format: :json }
    post "/unified-new-feed/consume" => "unified_new_feed_seen#consume",
      :constraints => { format: :json }
  end

  reloadable_patch do
    TopicQuery.prepend(DiscourseUnifiedNewFeed::TopicQueryExtension)
    TopicList.class_eval { attr_accessor :unconsumed_count }
  end

  add_to_serializer(:topic_list, :unconsumed_count, include_condition: -> {
    object.respond_to?(:unconsumed_count)
  }) { object.unconsumed_count }
end
