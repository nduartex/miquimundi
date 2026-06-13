class Group < ApplicationRecord
  belongs_to :tournament
  has_many :teams, dependent: :destroy
  has_one :group_result, dependent: :destroy
  has_many :group_standings, dependent: :destroy

  validates :name, presence: true
end
