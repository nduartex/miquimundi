class TournamentResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :balon_oro_player,  class_name: "Player", optional: true
  belongs_to :bota_oro_player,   class_name: "Player", optional: true
  belongs_to :guante_oro_player, class_name: "Player", optional: true
  belongs_to :young_player,      class_name: "Player", optional: true
  belongs_to :fair_play_team,    class_name: "Team",   optional: true
end
