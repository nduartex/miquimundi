require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "nav appears when signed in and hides when signed out" do
    SeedLoader.call
    user = User.create!(email: "p@x.com")

    get new_session_path
    assert_response :success
    assert_no_match "Cerrar", response.body
    assert_select "nav", false, "nav should not render when signed out"

    post session_path, params: { email: user.email }
    get rankings_path
    assert_response :success
    assert_select "nav"
    assert_match "Ranking", response.body
    assert_match "Mi Quiniela", response.body
  end
end
