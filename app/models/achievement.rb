class Achievement < ApplicationRecord
  belongs_to :quiniela
  validates :key, presence: true
end
