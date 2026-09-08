# frozen_string_literal: true

class AddForeignKeysToUnifiedNewFeedSeens < ActiveRecord::Migration[7.2]
  def up
    # Remove rows already orphaned by hard-deleted users/topics before
    # adding the constraints below, so they don't fail on existing data.
    execute <<~SQL
      DELETE FROM unified_new_feed_seens
      WHERE user_id NOT IN (SELECT id FROM users)
         OR topic_id NOT IN (SELECT id FROM topics)
    SQL

    add_foreign_key :unified_new_feed_seens,
      :users,
      column: :user_id,
      on_delete: :cascade

    add_foreign_key :unified_new_feed_seens,
      :topics,
      column: :topic_id,
      on_delete: :cascade
  end

  def down
    remove_foreign_key :unified_new_feed_seens, column: :user_id
    remove_foreign_key :unified_new_feed_seens, column: :topic_id
  end
end
