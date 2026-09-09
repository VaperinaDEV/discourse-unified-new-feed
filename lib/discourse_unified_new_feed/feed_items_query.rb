# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  # Reads UnifiedNewFeedItem (Topics tab only). This is deliberately
  # independent of TopicQuery/new state - once an item is queued, its
  # presence here (and so in the feed) depends only on our own table,
  # never on Discourse's live new/read state.
  class FeedItemsQuery
    def initialize(user)
      @user = user
    end

    def page(before_item_id: nil, limit:)
      scope = base_scope

      if before_item_id.present?
        anchor = UnifiedNewFeedItem.find_by(id: before_item_id, user_id: @user.id)
        scope = older_than(scope, anchor) if anchor
      end

      scope.limit(limit).to_a
    end

    def more_after?(item)
      older_than(base_scope, item).exists?
    end

    def self.count_for(user)
      UnifiedNewFeedItem.where(user_id: user.id).count
    end

    private

    def base_scope
      UnifiedNewFeedItem.where(user_id: @user.id).order(created_at: :desc, id: :desc)
    end

    def older_than(scope, item)
      scope.where(
        "(unified_new_feed_items.created_at < :created_at) OR " \
          "(unified_new_feed_items.created_at = :created_at AND unified_new_feed_items.id < :id)",
        created_at: item.created_at,
        id: item.id,
      )
    end
  end
end
