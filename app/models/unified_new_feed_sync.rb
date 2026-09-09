# frozen_string_literal: true

# Tracks, per user, when the queue was last topped up. Blank
# last_synced_at means the next sync is a full backfill, not incremental.
class UnifiedNewFeedSync < ActiveRecord::Base
  self.table_name = "unified_new_feed_syncs"

  belongs_to :user
end
