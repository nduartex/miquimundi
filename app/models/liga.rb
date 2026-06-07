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
  # Pure data rows with no callbacks/dependents → delete_all skips instantiation.
  has_many :activities, class_name: "LigaActivity", dependent: :delete_all

  validates :name, presence: true, length: { in: 3..40 }
  validates :max_players, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: MIN_PLAYERS, less_than_or_equal_to: MAX_PLAYERS }
  validates :invite_code, presence: true, uniqueness: true
  validate :cupo_not_below_current_members

  # Total prize pot, only meaningful when the liga has a prize. It is a plain
  # number (no currency): participants settle the money among themselves; the
  # app only computes the per-player share.
  # Upper bound keeps the value inside the 4-byte integer column: without it a
  # huge pot passes the Ruby-side numericality check and only blows up at save
  # time (ActiveModel::RangeError → unhandled 500). One billion is plenty.
  validates :prize_pot, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1_000_000_000 },
            if: :has_prize?
  before_validation :clear_prize_when_disabled
  before_validation :assign_invite_code, on: :create

  def full?
    memberships.count >= max_players
  end

  # The share each non-winner transfers to the winner: the pot split evenly
  # across all players, rounded to a whole number. Returns nil without a prize.
  def prize_share(players_count)
    return nil unless has_prize? && prize_pot && players_count.to_i.positive?
    (prize_pot.to_f / players_count).round
  end

  # Whether the pot divides evenly among the players (no rounding leftover).
  def prize_share_exact?(players_count)
    return false unless has_prize? && prize_pot && players_count.to_i.positive?
    (prize_pot % players_count).zero?
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

  # The cupo can be lowered, but never below the players already in the liga.
  def cupo_not_below_current_members
    return if max_players.blank? || new_record?

    current = memberships.count
    if current > max_players
      errors.add(:max_players, "no puede ser menor que los #{current} jugadores actuales")
    end
  end

  # A liga without a prize never keeps a stale pot around.
  def clear_prize_when_disabled
    self.prize_pot = nil unless has_prize?
  end

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
