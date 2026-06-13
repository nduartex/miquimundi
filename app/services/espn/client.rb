require "net/http"

module Espn
  # Thin HTTP client for ESPN's public (undocumented) soccer API. No key needed.
  # Raises Espn::Client::Error on any network/HTTP/parse failure so callers can
  # log and retry on the next sync cycle without corrupting data.
  class Client
    Error = Class.new(StandardError)

    SITE_BASE = "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world".freeze
    STANDINGS_URL = "https://site.api.espn.com/apis/v2/sports/soccer/fifa.world/standings".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    # dates: "YYYYMMDD" or "YYYYMMDD-YYYYMMDD"
    def scoreboard(dates:)
      get("#{SITE_BASE}/scoreboard?dates=#{dates}&limit=200")
    end

    def summary(event_id)
      get("#{SITE_BASE}/summary?event=#{event_id}")
    end

    def standings(season: 2026)
      get("#{STANDINGS_URL}?season=#{season}")
    end

    private

    def get(url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri, { "Accept" => "application/json" })
      end
      raise Error, "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "#{e.class}: #{e.message} (#{url})"
    end
  end
end
