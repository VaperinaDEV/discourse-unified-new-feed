# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  module TopicQueryExtension
    def list_unified_new(options = {})
      feed_options = @options.merge(options).dup
      feed_options[:filter] = "new"
      feed_options[:unordered] = true

      cursor_relation = unified_new_results(feed_options)
      topics = cursor_relation.to_a
      list = create_list(:new, { unordered: true }, topics)
      list.unconsumed_count = unified_new_count

      list
    end

    def unified_new_count
      unified_new_results(
        @options.merge(limit: false, page: nil).except(:before_bumped_at, :before_topic_id),
      ).reorder(nil).count(:id)
    end

    def unified_new_more?(options = {})
      unified_new_results(@options.merge(options).merge(limit: false)).limit(1).exists?
    end

    private

    def unified_new_results(options)
      options = options.dup
      consumed_scope = UnifiedNewFeedSeen.where(user_id: @user.id).select(:topic_id)
      options[:except_topic_ids] = consumed_scope

      results =
        case options[:subset]
        when "topics"
          new_results(options)
        when "replies"
          unread_results(options)
        else
          new_and_unread_results(options)
        end

      if (bumped_at = options[:before_bumped_at]).present? && (topic_id = options[:before_topic_id]).present?
        timestamp = Time.iso8601(bumped_at)
        results = results.where(
          "(topics.bumped_at < ?) OR (topics.bumped_at = ? AND topics.id < ?)",
          timestamp,
          timestamp,
          topic_id.to_i,
        )
      end

      results
    rescue ArgumentError
      results
    end
  end
end
