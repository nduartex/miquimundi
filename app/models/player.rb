class Player < ApplicationRecord
  belongs_to :team

  validates :name, presence: true

  def label
    "#{name} (#{team.name})"
  end
end
