# frozen_string_literal: true

class UnifiedNewFeedController < ListController
  def index
    unless DiscourseUnifiedNewFeed::GroupAccess.allowed_for?(current_user)
      return redirect_to path("/"), status: :found
    end

    per_page = TopicQuery::DEFAULT_PER_PAGE_COUNT
    list = params[:tab] == "reply" ? replies_list(per_page) : topics_list(per_page)

    list.unconsumed_topics_count = DiscourseUnifiedNewFeed::FeedItemsQuery.count_for(current_user)
    list.unconsumed_replies_count = TopicQuery.new(current_user).feed_unread_count

    respond_with_list(list)
  end

  private

  # Queue-backed: served from UnifiedNewFeedItem, topped up from core's
  # new_results.
  def topics_list(per_page)
    # Only top up on a fresh page load, not on "load more" pagination.
    DiscourseUnifiedNewFeed::FeedSync.sync!(current_user) if params[:before_item_id].blank?

    query = DiscourseUnifiedNewFeed::FeedItemsQuery.new(current_user)
    items = query.page(before_item_id: params[:before_item_id], limit: per_page)

    topics_by_id = Topic.secured(guardian).where(id: items.map(&:topic_id)).index_by(&:id)
    ordered_topics = items.filter_map { |item| topics_by_id[item.topic_id] }

    list = TopicQuery.new(current_user).create_list(:new, { unordered: true }, ordered_topics)

    if items.length == per_page && query.more_after?(items.last)
      list.more_topics_url = "/feed?tab=topic&before_item_id=#{items.last.id}"
    end

    list
  end

  # Fully live, no plugin state: driven entirely by Discourse's own
  # unread tracking, which this plugin never touches.
  def replies_list(per_page)
    topic_query = TopicQuery.new(current_user)

    topics = topic_query.feed_unread_topics(
      limit: per_page + 1,
      before_bumped_at: params[:before_bumped_at],
      before_topic_id: params[:before_topic_id],
    )

    has_more = topics.length > per_page
    topics = topics.first(per_page)

    list = topic_query.create_list(:unread, { unordered: true }, topics)

    if has_more && (last_topic = topics.last)
      list.more_topics_url =
        "/feed?tab=reply&before_bumped_at=#{last_topic.bumped_at.utc.iso8601}&before_topic_id=#{last_topic.id}"
    end

    list
  end
end
