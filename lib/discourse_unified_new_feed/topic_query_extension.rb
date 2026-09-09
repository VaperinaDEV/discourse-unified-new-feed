# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  module TopicQueryExtension
    # Candidate NEW topic ids for topping up the Topics queue. Reuses
    # core's own new-topic definition (consider_topics_new_when, via
    # new_topic_duration_minutes/new_since) via new_results - this
    # plugin never invents a parallel "is this new" rule of its own.
    #
    # since: nil means "take new_results as-is" (the first, backfill
    # sync for a user) - no extra date bound is layered on top, since
    # new_results already resolves the effective new-topic window
    # itself. A present since is only ever used for incremental
    # top-ups, to avoid re-scanning the whole new_results set every
    # time.
    #
    # Only used by FeedSync (backfill + incremental top-up); the
    # Topics tab itself is served from the queue table, not from a
    # live call to this method.
    def feed_new_topic_ids(since: nil)
      options = @options.merge(limit: false, page: nil).except(:before_bumped_at, :before_topic_id)

      relation = new_results(options)
      relation = relation.where("topics.created_at > ?", since) if since

      relation.reorder(nil).pluck(:id)
    end

    # Live Replies list. Reuses core's own unread definition
    # (unread_results / TopicUser tracking) directly, every call - no
    # plugin state is involved. A topic is here purely because
    # Discourse itself still considers it unread for this user, and it
    # will stop appearing the moment Discourse's own tracking says
    # there's nothing unread left, regardless of anything this plugin
    # has ever done with it before.
    #
    # Cursor/order are applied explicitly here rather than trusted to
    # @options, so pagination has a stable, unambiguous tie-break even
    # when several topics share a bumped_at.
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
