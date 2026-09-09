# frozen_string_literal: true

class RenameUnifiedNewFeedSeensToItems < ActiveRecord::Migration[7.2]
  def up
    rename_table :unified_new_feed_seens, :unified_new_feed_items

    remove_index :unified_new_feed_items, name: :idx_unified_new_feed_seens_user_topic
    remove_index :unified_new_feed_items, name: :idx_unified_new_feed_seens_topic

    # Old rows meant "already consumed" (seen). Under the new queue
    # semantics a row means "still pending" - the opposite meaning - so
    # old rows can't carry forward. Wipe them; the next per-user sync
    # (FeedSync) requeues everything currently new for that user, which
    # is exactly the one-time "initialization" pass.
    #
    # This table is now Topics-only: Replies has no persisted state at
    # all any more (see FeedSync / TopicQueryExtension#feed_unread_topics).
    execute "DELETE FROM unified_new_feed_items"

    add_index :unified_new_feed_items,
      %i[user_id topic_id],
      unique: true,
      name: :idx_unified_new_feed_items_user_topic

    add_index :unified_new_feed_items, :topic_id, name: :idx_unified_new_feed_items_topic

    add_index :unified_new_feed_items,
      %i[user_id created_at],
      name: :idx_unified_new_feed_items_user_created
  end

  def down
    remove_index :unified_new_feed_items, name: :idx_unified_new_feed_items_user_topic
    remove_index :unified_new_feed_items, name: :idx_unified_new_feed_items_topic
    remove_index :unified_new_feed_items, name: :idx_unified_new_feed_items_user_created

    execute "DELETE FROM unified_new_feed_items"

    rename_table :unified_new_feed_items, :unified_new_feed_seens

    add_index :unified_new_feed_seens,
      %i[user_id topic_id],
      unique: true,
      name: :idx_unified_new_feed_seens_user_topic

    add_index :unified_new_feed_seens, :topic_id, name: :idx_unified_new_feed_seens_topic
  end
end
