# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  # Populates UnifiedNewFeedItem (Topics tab only - Replies has no
  # table of its own) from Discourse's own new-topic state.
  #
  # "What counts as new" is entirely core's call (site default + the
  # user's own override), already resolved inside new_results. This
  # plugin never inspects either setting itself, it just takes
  # new_results as-is and layers a consumed-state on top.
  #
  # First call per user (no UnifiedNewFeedSync row yet) is a backfill:
  # takes new_results as-is, with no extra date bound. Every later call
  # is incremental, using our own last_synced_at watermark so it only
  # adds content created since last sync. An already-queued item only
  # leaves via the plugin's own consume flow (see
  # UnifiedNewFeedSeenController#consume), never by re-scanning.
  module FeedSync
    def self.sync!(user)
      return unless user

      sync_record = UnifiedNewFeedSync.find_or_initialize_by(user_id: user.id)
      sync_time = Time.current
      since = sync_record.last_synced_at

      topic_query = TopicQuery.new(user)
      enqueue(user, topic_query.feed_new_topic_ids(since: since))

      sync_record.last_synced_at = sync_time
      sync_record.save!
    end

    def self.enqueue(user, topic_ids)
      return if topic_ids.blank?

      already_queued = UnifiedNewFeedItem.where(user_id: user.id, topic_id: topic_ids).pluck(:topic_id)
      new_ids = topic_ids - already_queued
      return if new_ids.empty?

      now = Time.current
      rows = new_ids.map { |topic_id| { user_id: user.id, topic_id: topic_id, created_at: now, updated_at: now } }

      UnifiedNewFeedItem.insert_all(rows, unique_by: :idx_unified_new_feed_items_user_topic)
    end
  end
end
