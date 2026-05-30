class AwardPrediction < ApplicationRecord
  belongs_to :quiniela
  belongs_to :balon_oro_player,  class_name: "Player", optional: true
  belongs_to :bota_oro_player,   class_name: "Player", optional: true
  belongs_to :guante_oro_player, class_name: "Player", optional: true
  belongs_to :young_player,      class_name: "Player", optional: true
  belongs_to :fair_play_team,    class_name: "Team",   optional: true

  FIELDS = %i[balon_oro_player_id bota_oro_player_id guante_oro_player_id
              young_player_id fair_play_team_id].freeze

  def complete?
    FIELDS.all? { |f| public_send(f).present? }
  end
end
