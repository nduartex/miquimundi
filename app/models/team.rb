class Team < ApplicationRecord
  belongs_to :group
  has_many :players, dependent: :destroy

  validates :name, presence: true

  def label
    [flag_emoji, name].compact.join(" ")
  end
end
