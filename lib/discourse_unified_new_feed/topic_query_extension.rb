# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  module TopicQueryExtension
    # Candidate NEW topic ids for incremental Topics queue top-ups.
    # Incremental syncs use Discourse's new_results and add the plugin's
    # own watermark so previously scanned topics are not queried again.
    # The first seed is handled separately by feed_bootstrap_topic_ids.
    def feed_new_topic_ids(since: nil)
      options = @options.merge(limit: false, page: nil).except(:before_bumped_at, :before_topic_id)

      relation = new_results(options)
      relation = relation.where("topics.created_at > ?", since) if since

      relation.reorder(nil).pluck(:id)
    end

    # One-time bootstrap seed for a user's Topics feed. For the initial
    # feed population, use topic creation time plus Discourse's effective
    # "Consider topics new when" duration, but do not apply new_results'
    # user-created-at floor. Guardian-backed visibility is retained.
    # Private messages are excluded because the Topics feed is public-topic
    # content, not a PM inbox.
    def feed_bootstrap_topic_ids(created_after: nil)
      relation = Topic.secured(@guardian).where.not(archetype: Archetype.private_message)
      relation = relation.where("topics.created_at > ?", created_after) if created_after

      relation.reorder(created_at: :desc, id: :desc).pluck(:id)
    end

    # Live Replies list. Calls core's unread_results directly every
    # time - no plugin state involved.
    #
    # Cursor/order applied explicitly (not via @options) for a stable
    # tie-break when several topics share a bumped_at.
    def feed_unread_topics(limit:, before_bumped_at: nil, before_topic_id: nil)
      options = @options.merge(limit: false, page: nil).except(:before_bumped_at, :before_topic_id)

      relation = unread_results(options).reorder("topics.bumped_at DESC, topics.id DESC")

      if before_bumped_at.present? && before_topic_id.present?
        relation = relation.where(
          "(topics.bumped_at < :bumped_at) OR " \
            "(topics.bumped_at = :bumped_at AND topics.id < :id)",
          bumped_at: before_bumped_at,
          id: before_topic_id,
        )
      end

      relation.limit(limit).to_a
    end

    # Live count for the Replies tab label - same definition as
    # feed_unread_topics, just count instead of fetch.
    def feed_unread_count
      options = @options.merge(limit: false, page: nil).except(:before_bumped_at, :before_topic_id)
      unread_results(options).reorder(nil).count(:id)
    end
  end
end
