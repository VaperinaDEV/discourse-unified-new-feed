# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  # Populates UnifiedNewFeedItem (Topics tab only - Replies has no
  # table of its own, see TopicQueryExtension#feed_unread_topics) from
  # Discourse's own new-topic state.
  #
  # The first call for a user (no UnifiedNewFeedSync row yet) is a
  # backfill with NO extra date bound of our own: it takes core's
  # new_results as-is. new_results already resolves the effective
  # "consider topics new when" window itself (the user's own
  # new_topic_duration_minutes, falling back to the site default,
  # including the "always"/"last visit" special cases) together with
  # new_since, so for a brand-new user this naturally seeds "topics
  # created within that window", and for an existing user it naturally
  # excludes anything they've already effectively seen. This plugin
  # does not re-derive or duplicate that window - it only decides what
  # happens to an item *after* it's been surfaced as new. This is the
  # one-time "initialization" per user.
  #
  # Every later call is incremental: only topics created after the
  # last sync are considered, so it never re-scans the whole
  # currently-new set - it only ever adds genuinely new content since
  # last time. Whether an already-queued item stays in the feed
  # depends solely on its UnifiedNewFeedItem row still existing, which
  # only the plugin's own consume flow controls (viewport dwell, see
  # UnifiedNewFeedSeenController#consume) - never Discourse's read
  # state, and never a re-scan of new_results.
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
