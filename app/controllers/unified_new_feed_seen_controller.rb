# frozen_string_literal: true

# Topics-only. The Replies tab never calls this - it has no consumed
# state, it relies entirely on Discourse's own read tracking.
class UnifiedNewFeedSeenController < ApplicationController
  requires_login

  def consume
    topic_ids = Array(params[:topic_ids]).filter_map do |value|
      Integer(value, 10)
    rescue ArgumentError, TypeError
      nil
    end.uniq.first(SiteSetting.unified_new_feed_batch_size)

    return render json: success_json.merge(topic_ids: []) if topic_ids.empty?

    consumed_ids =
      UnifiedNewFeedItem.where(user_id: current_user.id, topic_id: topic_ids).pluck(:topic_id)

    return render json: success_json.merge(topic_ids: []) if consumed_ids.empty?

    UnifiedNewFeedItem.where(user_id: current_user.id, topic_id: consumed_ids).delete_all

    render json: success_json.merge(topic_ids: consumed_ids)
  end
end
