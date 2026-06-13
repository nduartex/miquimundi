namespace :espn do
  desc "Mapeo inicial: crea los partidos de grupos, asigna espn_ids y hace backfill de goles/standings (todo el torneo)"
  task map: :environment do
    tournament = Tournament.order(:year).last
    abort "No hay torneo" unless tournament

    service = Espn::SyncService.new(tournament)
    summary = service.sync!(dates: Espn::SyncService::TOURNAMENT_DATES, standings: :force)

    puts "Eventos ESPN procesados: #{summary[:events]}"
    puts "Partidos en BD: #{tournament.matches.where(phase: 'group').count} de grupos, " \
         "#{tournament.matches.knockout.where.not(espn_id: nil).count} KO mapeados"
    puts "Equipos con espn_id: #{Team.where.not(espn_id: nil).count}/48"
    puts "Standings: #{GroupStanding.count} filas · Goles: #{Goal.count}"
    if service.unmatched.any?
      puts "⚠ Equipos ESPN sin mapear (añadir a CODE_ALIASES):"
      service.unmatched.each { |u| puts "  - #{u}" }
    end
  end

  desc "Una corrida del sync (ventana de hoy), como lo haría el job recurrente"
  task sync: :environment do
    EspnSyncJob.perform_now(force: true)
    tournament = Tournament.order(:year).last
    live = tournament.matches.where(status: "live").count
    finished = tournament.matches.where(status: "finished").count
    puts "Sync OK · en vivo: #{live} · terminados: #{finished} · goles: #{Goal.count}"
  end
end
