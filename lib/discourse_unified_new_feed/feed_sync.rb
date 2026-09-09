# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  # Populates UnifiedNewFeedItem (Topics tab only - Replies has no
  # table of its own, see TopicQueryExtension#feed_unread_topics) from
  # Discourse's own new-topic state.
  #
  # "What counts as new" is entirely Discourse's call, at two levels
  # this plugin never reads or reasons about itself:
  #   - the site-wide default (default_other_new_topic_duration_minutes)
  #   - the user's own override ("Consider topics new when", stored on
  #     user_option.new_topic_duration_minutes)
  # Both are already resolved together (plus new_since, plus the
  # "always"/"last visit" special cases) inside core's own new_results.
  # This plugin only ever calls new_results and uses its result as-is -
  # it never inspects either setting, never computes a duration itself,
  # and never re-derives a competing "is this new" window. Its only job
  # is the consumed-state layer on top of whatever new_results returns.
  #
  # The first call for a user (no UnifiedNewFeedSync row yet) is a
  # backfill with NO extra date bound of our own: it takes new_results
  # as-is, so for a brand-new user this naturally seeds "topics within
  # their effective new-topic window", and for an existing user it
  # naturally excludes anything they've already effectively seen. This
  # is the one-time "initialization" per user.
  #
  # Every later call is incremental: only topics created after the
  # last sync are considered (via our own last_synced_at watermark,
  # not Discourse's new-topic window), so it never re-scans the whole
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
