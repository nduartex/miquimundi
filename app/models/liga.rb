class Liga < ApplicationRecord
  # Code alphabet without ambiguous characters (no 0/O/1/I/L) so it is easy to
  # read out loud and type.
  CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze
  CODE_LENGTH = 6
  MIN_PLAYERS = 2
  MAX_PLAYERS = 50

  belongs_to :creator, class_name: "User"
  belongs_to :tournament
  has_many :memberships, class_name: "LigaMembership", dependent: :destroy
  has_many :members, through: :memberships, source: :user

  validates :name, presence: true, length: { in: 3..40 }
  validates :max_players, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: MIN_PLAYERS, less_than_or_equal_to: MAX_PLAYERS }
  validates :invite_code, presence: true, uniqueness: true

  before_validation :assign_invite_code, on: :create

  def full?
    memberships.count >= max_players
  end

  def member?(user)
    return false unless user
    memberships.exists?(user_id: user.id)
  end

  def creator?(user)
    user.present? && creator_id == user.id
  end

  # The creator may delete the liga only once nobody else remains.
  def deletable_by?(user)
    creator?(user) && memberships.count <= 1
  end

  private

  def assign_invite_code
    return if invite_code.present?

    loop do
      candidate = Array.new(CODE_LENGTH) { CODE_ALPHABET.sample }.join
      unless self.class.exists?(invite_code: candidate)
        self.invite_code = candidate
        break
      end
    end
  end
end
