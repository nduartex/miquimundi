namespace :players do
  desc "Sincroniza rosters (equipos + jugadores + posiciones) desde el YAML, sin tocar el torneo ni el bracket. Seguro para producción."
  task sync: :environment do
    counts = SeedLoader.sync_players
    Rails.cache.delete_matched("datasets/v3/players/*") rescue Rails.cache.clear

    gk = Player.where(position: "goalkeeper").count
    puts "Rosters sincronizados: #{counts[:teams]} equipos, " \
         "#{counts[:created]} jugadores nuevos, #{counts[:updated]} posiciones actualizadas " \
         "(#{Player.count} jugadores totales, #{gk} porteros). Caché de typeahead limpiada."
  end
end
