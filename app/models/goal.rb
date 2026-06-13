class Goal < ApplicationRecord
  belongs_to :match
  belongs_to :team
  belongs_to :player, optional: true

  validates :player_name, presence: true

  scope :in_order, -> { order(:sort_order) }
  # Tournament scorer table: own goals credit no one.
  scope :scored, -> { where(own_goal: false) }
end
