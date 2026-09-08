# frozen_string_literal: true

class CreateUnifiedNewFeedSeens < ActiveRecord::Migration[7.2]
  def change
    create_table :unified_new_feed_seens do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.timestamps null: false
    end

    add_index :unified_new_feed_seens,
      %i[user_id topic_id],
      unique: true,
      name: :idx_unified_new_feed_seens_user_topic

    add_index :unified_new_feed_seens,
      :topic_id,
      name: :idx_unified_new_feed_seens_topic
  end
end
