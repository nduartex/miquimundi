class Tournament < ApplicationRecord
  has_many :groups, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_one :tournament_result, dependent: :destroy

  validates :name, :year, presence: true

  def self.current
    order(year: :desc).first
  end

  def locked?
    locked_at.present? && locked_at <= Time.current
  end
end
