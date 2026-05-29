class AwardPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :top_scorer_player, class_name: "Player", optional: true
  belongs_to :top_assists_player, class_name: "Player", optional: true
end
