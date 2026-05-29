require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "nav appears when signed in and hides when signed out" do
    SeedLoader.call
    user = User.create!(username: "navuser")

    get new_session_path
    assert_response :success
    assert_no_match "Cerrar", response.body
    assert_select "nav", false, "nav should not render when signed out"

    get restore_path(token: user.access_token)
    get rankings_path
    assert_response :success
    assert_select "nav"
    assert_match "Ranking", response.body
    assert_match "Mi Quiniela", response.body
  end
end
