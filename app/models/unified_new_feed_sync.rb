# frozen_string_literal: true

# Tracks, per user, when the feed queue was last topped up from
# Discourse's live "new"/"unread" state. A blank last_synced_at means
# the user has never been initialized yet - the next sync will be a
# full backfill instead of an incremental one.
class UnifiedNewFeedSync < ActiveRecord::Base
  self.table_name = "unified_new_feed_syncs"

  belongs_to :user
end
