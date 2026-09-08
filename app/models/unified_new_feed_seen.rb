# frozen_string_literal: true

class UnifiedNewFeedSeen < ActiveRecord::Base
  self.table_name = "unified_new_feed_seens"

  belongs_to :user
  belongs_to :topic

  validates :user_id, :topic_id, presence: true
end
