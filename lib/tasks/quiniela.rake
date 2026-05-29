namespace :quiniela do
  desc "Carga resultados reales desde db/results.yml y recalcula puntajes"
  task load_results: :environment do
    tournament = Tournament.current
    abort("No hay torneo cargado. Corre bin/rails db:seed") if tournament.nil?

    data = YAML.safe_load_file(Rails.root.join("db/results.yml"))
    Results::ManualProvider.new(tournament, data).apply!
    puts "Resultados aplicados. Recalculando puntajes..."
    RecalculateScoresJob.perform_now(tournament.id)
    puts "Listo. #{tournament.quinielas_relation.count} quinielas recalculadas."
  end

  desc "Recalcula puntajes de todas las quinielas"
  task recalculate: :environment do
    tournament = Tournament.current
    abort("No hay torneo cargado.") if tournament.nil?
    RecalculateScoresJob.perform_now(tournament.id)
    puts "Recalculo completo."
  end
end
