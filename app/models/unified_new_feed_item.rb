# frozen_string_literal: true

# A row here means "this topic is still pending (unconsumed) in the
# user's Topics feed". Consuming an item deletes its row - there is no
# separate permanent "seen" ledger.
#
# Topics-only: the Replies tab has no state of its own at all (see
# DiscourseUnifiedNewFeed::TopicQueryExtension#feed_unread_topics),
# since it relies entirely on Discourse's own read/unread tracking.
class UnifiedNewFeedItem < ActiveRecord::Base
  self.table_name = "unified_new_feed_items"

  belongs_to :user
  belongs_to :topic

  validates :user_id, :topic_id, presence: true
end
