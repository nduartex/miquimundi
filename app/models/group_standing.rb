class GroupStanding < ApplicationRecord
  belongs_to :group
  belongs_to :team

  validates :team_id, uniqueness: { scope: :group_id }

  scope :ranked, -> { order(Arel.sql("rank NULLS LAST"), points: :desc, goal_difference: :desc) }
end
