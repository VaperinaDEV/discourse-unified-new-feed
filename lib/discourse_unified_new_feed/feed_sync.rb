# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  # Populates UnifiedNewFeedItem for the Topics tab. The first sync uses
  # the effective "Consider topics new when" window, based on topic
  # creation time only. Later syncs use the plugin's own timestamp
  # watermark and only add topics created since the previous sync.
  module FeedSync
    def self.sync!(user)
      return unless user

      sync_record = UnifiedNewFeedSync.find_or_initialize_by(user_id: user.id)
      sync_time = Time.current
      topic_query = TopicQuery.new(user)

      if sync_record.last_synced_at.nil?
        cutoff = bootstrap_cutoff(user)
        topic_ids = topic_query.feed_bootstrap_topic_ids(created_after: cutoff)
        enqueue(user, topic_ids)

        # Keep an empty bootstrap retryable.
        return if topic_ids.blank?
      else
        topic_ids = topic_query.feed_new_topic_ids(since: sync_record.last_synced_at)
        enqueue(user, topic_ids)
      end

      sync_record.last_synced_at = sync_time
      sync_record.save!
    end

    # Uses the same effective duration as Discourse's user option:
    # the user's override when present, otherwise the site default.
    # The special values do not provide a finite window, so the bootstrap
    # is intentionally unbounded for those cases.
    def self.bootstrap_cutoff(user)
      minutes = user.user_option&.new_topic_duration_minutes
      minutes = SiteSetting.default_other_new_topic_duration_minutes if minutes.nil?

      case minutes.to_i
      when ::User::NewTopicDuration::ALWAYS, ::User::NewTopicDuration::LAST_VISIT
        nil
      else
        minutes.to_i.minutes.ago
      end
    end

    def self.enqueue(user, topic_ids)
      return if topic_ids.blank?

      already_queued = UnifiedNewFeedItem.where(user_id: user.id, topic_id: topic_ids).pluck(:topic_id)
      new_ids = topic_ids - already_queued
      return if new_ids.empty?

      now = Time.current
      rows = new_ids.map do |topic_id|
        { user_id: user.id, topic_id: topic_id, created_at: now, updated_at: now }
      end

      UnifiedNewFeedItem.insert_all(rows, unique_by: :idx_unified_new_feed_items_user_topic)
    end
  end
end
