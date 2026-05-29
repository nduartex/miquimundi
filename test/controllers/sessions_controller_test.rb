require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "logging in with a new email creates a user and session" do
    assert_difference "User.count", 1 do
      post session_path, params: { email: "new@user.com" }
    end
    assert_redirected_to quiniela_path
  end

  test "logging in with existing email reuses the user" do
    User.create!(email: "old@user.com")
    assert_no_difference "User.count" do
      post session_path, params: { email: "OLD@user.com" }
    end
  end

  test "rejects invalid email" do
    post session_path, params: { email: "nope" }
    assert_response :unprocessable_entity
  end

  test "login stores the chosen favorite team" do
    SeedLoader.call
    team = Team.find_by(code: "ARG")
    post session_path, params: { email: "fan@x.com", favorite_team_id: team.id }
    assert_equal team.id, User.find_by(email: "fan@x.com").favorite_team_id
  end

  test "login hero shows the logo, hook and World Cup countdown" do
    get new_session_path
    assert_response :success
    assert_select "img[alt=?]", "MiquiMundi — Mi Quiniela Mundialista 2026"
    assert_match "compite con tus amigos", response.body          # hook copy
    assert_match 'data-controller="countdown"', response.body     # live countdown
    assert_select "[data-countdown-target=days]"                  # countdown tiles
  end
end
