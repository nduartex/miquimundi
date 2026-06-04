class LigaMembership < ApplicationRecord
  belongs_to :liga
  belongs_to :user

  validates :user_id, uniqueness: { scope: :liga_id, message: "ya está en esta liga" }
end
