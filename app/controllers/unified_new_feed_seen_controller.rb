# frozen_string_literal: true

class UnifiedNewFeedSeenController < ApplicationController
  requires_login

  def consume
    topic_ids = Array(params[:topic_ids]).filter_map do |value|
      Integer(value, 10)
    rescue ArgumentError, TypeError
      nil
    end.uniq.first(SiteSetting.unified_new_feed_batch_size)

    return render json: success_json if topic_ids.empty?

    existing_topic_ids = Topic.where(id: topic_ids).pluck(:id)
    return render json: success_json if existing_topic_ids.empty?

    already_consumed =
      UnifiedNewFeedSeen
        .where(user_id: current_user.id, topic_id: existing_topic_ids)
        .pluck(:topic_id)

    new_topic_ids = existing_topic_ids - already_consumed
    return render json: success_json.merge(topic_ids: []) if new_topic_ids.empty?

    now = Time.current
    rows = new_topic_ids.map do |topic_id|
      {
        user_id: current_user.id,
        topic_id: topic_id,
        created_at: now,
        updated_at: now,
      }
    end

    UnifiedNewFeedSeen.insert_all(
      rows,
      unique_by: :idx_unified_new_feed_seens_user_topic,
    )

    render json: success_json.merge(topic_ids: new_topic_ids)
  end
end
