# frozen_string_literal: true

class UnifiedNewFeedController < ListController
  def index
    unless DiscourseUnifiedNewFeed::GroupAccess.allowed_for?(current_user)
      return redirect_to path("/"), status: :found
    end

    list_options = {
      per_page: TopicQuery::DEFAULT_PER_PAGE_COUNT,
      page: nil,
      before_bumped_at: params[:before_bumped_at],
      before_topic_id: params[:before_topic_id],
    }.compact

    query = TopicQuery.new(current_user, list_options)
    list = query.list_unified_new
    topics = list.topics

    if topics.length >= list.per_page && query.unified_new_more?
      last_topic = topics.last
      list.more_topics_url =
        "/feed?before_bumped_at=#{ERB::Util.url_encode(last_topic.bumped_at.iso8601)}&before_topic_id=#{last_topic.id}"
    end

    respond_with_list(list)
  end
end
