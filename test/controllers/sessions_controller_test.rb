require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  # Honeypot --------------------------------------------------------------

  test "a filled honeypot field silently blocks registration" do
    assert_no_difference "User.count" do
      post session_path, params: valid_signup(username: "botuser", nickname: "i am a bot")
    end
    assert_response :unprocessable_entity
  end

  # Time-trap -------------------------------------------------------------

  test "rejects a submission with no timestamp" do
    assert_no_difference "User.count" do
      post session_path, params: { username: "newbie" }
    end
    assert_response :unprocessable_entity
    assert_match(/expir/i, response.body)
  end

  test "rejects a forged timestamp" do
    assert_no_difference "User.count" do
      post session_path, params: { username: "newbie", signup_ts: "not-a-valid-token" }
    end
    assert_response :unprocessable_entity
  end

  test "rejects a suspiciously fast submission" do
    assert_no_difference "User.count" do
      post session_path, params: valid_signup(username: "newbie", age: 0.3)
    end
    assert_response :unprocessable_entity
  end

  test "rejects an expired form" do
    assert_no_difference "User.count" do
      post session_path, params: valid_signup(username: "newbie", age: 3.hours.to_f)
    end
    assert_response :unprocessable_entity
    assert_match(/expir/i, response.body)
  end

  # Registration ----------------------------------------------------------

  test "registering a new username creates a user and session" do
    assert_difference "User.count", 1 do
      post session_path, params: valid_signup(username: "newbie")
    end
    assert_redirected_to quiniela_path(welcome: 1)
  end

  test "an existing username is rejected (no impersonation, no duplicate)" do
    User.create!(username: "taken")
    assert_no_difference "User.count" do
      post session_path, params: valid_signup(username: "taken")
    end
    assert_response :unprocessable_entity
  end

  test "rejects an invalid username" do
    post session_path, params: valid_signup(username: "no")
    assert_response :unprocessable_entity
  end

  test "stores the chosen favorite team" do
    SeedLoader.call
    team = Team.find_by(code: "ARG")
    post session_path, params: valid_signup(username: "hincha", favorite_team_id: team.id)
    assert_equal team.id, User.find_by(username: "hincha").favorite_team_id
  end

  # Rate limiting ---------------------------------------------------------

  test "allows a burst of 3 signups but blocks the 4th from the same network" do
    3.times { |i| post session_path, params: valid_signup(username: "burst#{i}") }
    assert_equal 3, User.count

    assert_no_difference "User.count" do
      post session_path, params: valid_signup(username: "burst3")
    end
    assert_response :too_many_requests
  end

  test "blocks the 11th signup within an hour from the same network" do
    10.times do |i|
      post session_path, params: valid_signup(username: "hourly#{i}")
      travel 31.seconds # clear the 30s burst window, stay within the hour
    end
    assert_equal 10, User.count

    assert_no_difference "User.count" do
      post session_path, params: valid_signup(username: "hourly10")
    end
    assert_response :too_many_requests
  end

  test "different networks have independent signup limits" do
    3.times { |i| post session_path, params: valid_signup(username: "redA#{i}"), headers: { "REMOTE_ADDR" => "1.1.1.1" } }
    post session_path, params: valid_signup(username: "redA3"), headers: { "REMOTE_ADDR" => "1.1.1.1" }
    assert_response :too_many_requests # 1.1.1.1 is now blocked

    assert_difference "User.count", 1 do
      post session_path, params: valid_signup(username: "fromB"), headers: { "REMOTE_ADDR" => "2.2.2.2" }
    end
  end

  test "validation errors do not consume the signup limit" do
    3.times { post session_path, params: valid_signup(username: "no") } # too short → 422, no creation
    assert_equal 0, User.count

    assert_difference "User.count", 1 do
      post session_path, params: valid_signup(username: "valid_one")
    end
  end

  test "the raw request guard blocks hammering the endpoint" do
    20.times { post session_path, params: valid_signup(username: "x", nickname: "bot") } # tripped honeypot, but each request counts
    post session_path, params: valid_signup(username: "x", nickname: "bot")
    assert_response :too_many_requests
  end

  # Restore / login -------------------------------------------------------

  test "restore via the personal access link logs the user back in" do
    SeedLoader.call
    user = User.create!(username: "returns")
    get restore_path(token: user.access_token)
    assert_redirected_to quiniela_path
    get quiniela_path
    assert_response :success # session is set
  end

  test "an invalid access link is rejected" do
    get restore_path(token: "nope")
    assert_redirected_to new_session_path
  end

  # Login hero ------------------------------------------------------------

  test "login hero shows the logo, hook and World Cup countdown" do
    get new_session_path
    assert_response :success
    assert_select "img[alt=?]", "MiquiMundi — Mi Quiniela Mundialista 2026"
    assert_match "compite con tus amigos", response.body
    assert_match 'data-controller="countdown"', response.body
    assert_select "[data-countdown-target=days]"
  end

  test "the registration form carries the invisible anti-bot fields" do
    get new_session_path
    assert_select "input[name=nickname]"                  # honeypot
    assert_select "input[name=signup_ts][type=hidden]"    # signed timestamp
  end

  test "a freshly rendered form passes the time-trap after a human pause" do
    get new_session_path
    ts = css_select("input[name=signup_ts]").first["value"]
    # travel_to truncates sub-seconds, so travel a comfortable margin past the
    # 2.5s minimum to avoid a fractional-second false negative in tests.
    travel 5.seconds
    assert_difference "User.count", 1 do
      post session_path, params: { username: "realhuman", signup_ts: ts, nickname: "" },
           headers: { "REMOTE_ADDR" => "203.0.113.7" }
    end
  end

  test "after a validation error the re-rendered form keeps a usable timestamp" do
    User.create!(username: "takenx")
    get new_session_path
    ts = css_select("input[name=signup_ts]").first["value"]
    travel 5.seconds

    # First try: username already taken → 422, form re-renders.
    post session_path, params: { username: "takenx", signup_ts: ts, nickname: "" },
         headers: { "REMOTE_ADDR" => "198.51.100.9" }
    assert_response :unprocessable_entity
    retry_ts = css_select("input[name=signup_ts]").first["value"]
    assert retry_ts.present?, "the re-rendered form must still carry a signup timestamp"

    # Retry with a good username using the re-rendered form → should succeed.
    travel 3.seconds
    assert_difference "User.count", 1 do
      post session_path, params: { username: "freshname", signup_ts: retry_ts, nickname: "" },
           headers: { "REMOTE_ADDR" => "198.51.100.9" }
    end
  end

  private

  # Params that satisfy the anti-bot guards: empty honeypot + a validly signed
  # timestamp aged `age` seconds (default well past the min human fill time).
  def valid_signup(age: 5.0, **extra)
    ts = Rails.application.message_verifier(:signup).generate(Time.current.to_f - age)
    { username: "newbie", signup_ts: ts }.merge(extra)
  end
end
