class TournamentResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :top_scorer_player, class_name: "Player", optional: true
  belongs_to :top_assists_player, class_name: "Player", optional: true
end
