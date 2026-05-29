class Match < ApplicationRecord
  PHASES = %w[group round_16 quarter semi final].freeze
  STATUSES = %w[scheduled live finished].freeze
  MULTIPLIERS = { "round_16" => 1.0, "quarter" => 1.5, "semi" => 2.0, "final" => 3.0 }.freeze

  belongs_to :tournament
  belongs_to :home_team, class_name: "Team", optional: true
  belongs_to :away_team, class_name: "Team", optional: true
  belongs_to :penalty_winner, class_name: "Team", optional: true
  has_many :match_predictions, dependent: :destroy

  validates :phase, inclusion: { in: PHASES }
  validates :status, inclusion: { in: STATUSES }

  scope :knockout, -> { where.not(phase: "group") }
  scope :ordered, -> { order(:kickoff_at) }

  def knockout?
    phase != "group"
  end

  def multiplier
    MULTIPLIERS.fetch(phase, 1.0)
  end

  def locked?
    kickoff_at.present? && kickoff_at <= Time.current
  end

  def finished?
    status == "finished" && home_goals.present? && away_goals.present?
  end

  def actual_winner_team_id
    return nil unless finished?
    return home_team_id if home_goals > away_goals
    return away_team_id if away_goals > home_goals
    nil
  end
end
