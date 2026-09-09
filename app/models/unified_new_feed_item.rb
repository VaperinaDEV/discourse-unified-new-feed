# frozen_string_literal: true

# A row means "still pending" in the user's Topics feed; consuming an
# item deletes it - no separate "seen" ledger. Topics-only: Replies has
# no state of its own (see TopicQueryExtension#feed_unread_topics).
class UnifiedNewFeedItem < ActiveRecord::Base
  self.table_name = "unified_new_feed_items"

  belongs_to :user
  belongs_to :topic

  validates :user_id, :topic_id, presence: true
end
