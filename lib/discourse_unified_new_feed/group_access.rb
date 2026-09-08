# frozen_string_literal: true

module DiscourseUnifiedNewFeed
  module GroupAccess
    def self.allowed_for?(user)
      return false if user.blank?

      configured_groups = SiteSetting.unified_new_feed_groups
      return true if configured_groups.blank?

      group_ids = (
        Array(configured_groups).flat_map { |value| value.to_s.split("|") }
      ).filter_map do |value|
        Integer(value, 10) rescue nil
      end.uniq

      user.group_ids.any? { |group_id| group_ids.include?(group_id) }
    end
  end
end
