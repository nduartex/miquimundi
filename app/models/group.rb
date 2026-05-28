class Group < ApplicationRecord
  belongs_to :tournament
  has_many :teams, dependent: :destroy
  has_one :group_result, dependent: :destroy

  validates :name, presence: true
end
