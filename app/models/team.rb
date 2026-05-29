class Team < ApplicationRecord
  belongs_to :group
  has_many :players, dependent: :destroy

  validates :name, presence: true

  # Name first, flag on the right, no country code/abbreviation.
  def label
    [name, flag_emoji].compact.join("  ")
  end
end
