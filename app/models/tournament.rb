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

  # Late window: after kickoff, users who never completed their first part can
  # still fill it (with a scoring penalty) until late_deadline_at — the start
  # of group matchday 3, when every team has played at most 2 matches.
  def late_window_open?
    locked? && late_deadline_at.present? && late_deadline_at > Time.current
  end

  def quinielas_relation
    Quiniela.where(tournament_id: id)
  end

  # Knockout predictions open once the real group stage has finished, i.e. all
  # 12 groups have an official result loaded.
  def knockout_open?
    return false if groups.empty?
    GroupResult.where(group_id: groups.select(:id)).count >= groups.count
  end

  # The tournament is over once the final has an official result. Used to switch
  # liga prizes from "provisional" to "final" (winner = 1st in the ranking).
  def finished?
    matches.find_by(phase: "final")&.finished? || false
  end
end
