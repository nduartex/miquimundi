class User < ApplicationRecord
  has_many :quinielas, dependent: :destroy

  EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  before_validation { self.email = email.to_s.downcase.strip }

  validates :email, presence: true, uniqueness: true, format: { with: EMAIL_REGEX }

  def display_name
    name.presence || email
  end

  def quiniela_for(tournament)
    quinielas.find_or_initialize_by(tournament: tournament)
  end
end
