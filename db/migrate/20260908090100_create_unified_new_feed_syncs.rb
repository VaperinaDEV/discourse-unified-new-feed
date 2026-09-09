# frozen_string_literal: true

class CreateUnifiedNewFeedSyncs < ActiveRecord::Migration[7.2]
  def change
    create_table :unified_new_feed_syncs do |t|
      t.integer :user_id, null: false
      t.datetime :last_synced_at
      t.timestamps null: false
    end

    add_index :unified_new_feed_syncs, :user_id, unique: true, name: :idx_unified_new_feed_syncs_user
  end
end
