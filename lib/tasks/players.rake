namespace :players do
  desc "Sincroniza rosters (equipos + jugadores + posiciones) desde el YAML, sin tocar el torneo ni el bracket. Seguro para producción."
  task sync: :environment do
    counts = SeedLoader.sync_players
    # SolidCache no soporta delete_matched: borramos la clave puntual del
    # dataset del typeahead por torneo (debe coincidir con players_dataset).
    Tournament.ids.each { |id| Rails.cache.delete("datasets/v3/players/#{id}") }

    gk = Player.where(position: "goalkeeper").count
    puts "Rosters sincronizados: #{counts[:teams]} equipos, " \
         "#{counts[:created]} jugadores nuevos, #{counts[:updated]} posiciones actualizadas " \
         "(#{Player.count} jugadores totales, #{gk} porteros). Caché de typeahead limpiada."
  end
end
