# frozen_string_literal: true

class AddForeignKeyToUnifiedNewFeedSyncs < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM unified_new_feed_syncs
      WHERE user_id NOT IN (SELECT id FROM users)
    SQL

    add_foreign_key :unified_new_feed_syncs,
      :users,
      column: :user_id,
      on_delete: :cascade
  end

  def down
    remove_foreign_key :unified_new_feed_syncs, column: :user_id
  end
end
