require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "registering a new username creates a user and session" do
    assert_difference "User.count", 1 do
      post session_path, params: { username: "newbie" }
    end
    assert_redirected_to quiniela_path(welcome: 1)
  end

  test "an existing username is rejected (no impersonation, no duplicate)" do
    User.create!(username: "taken")
    assert_no_difference "User.count" do
      post session_path, params: { username: "taken" }
    end
    assert_response :unprocessable_entity
  end

  test "rejects an invalid username" do
    post session_path, params: { username: "no" }
    assert_response :unprocessable_entity
  end

  test "stores the chosen favorite team" do
    SeedLoader.call
    team = Team.find_by(code: "ARG")
    post session_path, params: { username: "hincha", favorite_team_id: team.id }
    assert_equal team.id, User.find_by(username: "hincha").favorite_team_id
  end

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

  test "login hero shows the logo, hook and World Cup countdown" do
    get new_session_path
    assert_response :success
    assert_select "img[alt=?]", "MiquiMundi — Mi Quiniela Mundialista 2026"
    assert_match "compite con tus amigos", response.body
    assert_match 'data-controller="countdown"', response.body
    assert_select "[data-countdown-target=days]"
  end
end
