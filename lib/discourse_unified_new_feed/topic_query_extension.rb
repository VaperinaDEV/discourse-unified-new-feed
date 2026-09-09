# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  module TopicQueryExtension
    # Candidate NEW topic ids for topping up the Topics queue. Reuses
    # core's new_results as-is (site + per-user "new" settings already
    # resolved there); this plugin computes no duration of its own.
    #
    # since: nil takes new_results as-is (first backfill sync). A
    # present value is this plugin's own last-sync watermark, used for
    # incremental top-ups so we don't re-scan the whole new_results set.
    #
    # Used only by FeedSync - the Topics tab itself reads the queue
    # table, not this method.
    def feed_new_topic_ids(since: nil)
      options = @options.merge(limit: false, page: nil).except(:before_bumped_at, :before_topic_id)

      relation = new_results(options)
      relation = relation.where("topics.created_at > ?", since) if since

      relation.reorder(nil).pluck(:id)
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
