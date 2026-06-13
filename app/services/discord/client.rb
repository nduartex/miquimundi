require "net/http"

module Discord
  # Thin HTTP client that POSTs a JSON payload to a Discord webhook URL. Mirrors
  # Espn::Client: explicit timeouts and a single Error wrapper so callers (the
  # delivery job) can log and move on without ever bubbling a raw network error.
  # Discord answers 204 No Content on success — any 2xx is accepted, body unread.
  class Client
    Error = Class.new(StandardError)

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    def post(webhook_url, payload)
      uri = URI(webhook_url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
        request.body = JSON.generate(payload)
        http.request(request)
      end
      raise Error, "HTTP #{response.code} for webhook" unless response.is_a?(Net::HTTPSuccess)
      true
    rescue SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "#{e.class}: #{e.message}"
    end
  end
end
