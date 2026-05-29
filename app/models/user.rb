class User < ApplicationRecord
  has_many :quinielas, dependent: :destroy
  belongs_to :favorite_team, class_name: "Team", optional: true

  USERNAME_REGEX = /\A[a-zA-Z0-9_.\-]{3,20}\z/

  before_validation { self.username = username.to_s.strip }
  has_secure_token :access_token

  validates :username, presence: true, uniqueness: { case_sensitive: false },
            format: { with: USERNAME_REGEX, message: "usa 3-20 letras, números, . _ -" }

  def display_name
    name.presence || username
  end

  def quiniela_for(tournament)
    quinielas.find_or_initialize_by(tournament: tournament)
  end
end
