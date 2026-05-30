require "test_helper"

class SharedQuinielasControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @owner = User.create!(username: "sharer")
    @quiniela = @owner.quinielas.create!(tournament: @tournament, submitted_at: Time.current)
    g = @tournament.groups.order(:name).first
    t = g.teams.to_a
    @quiniela.group_predictions.create!(
      group: g, first_team: t[0], second_team: t[1], third_team: t[2], fourth_team: t[3]
    )
  end

  test "renders the shared quiniela read-only without a login" do
    get shared_quiniela_path(token: @quiniela.share_token)
    assert_response :success
    assert_includes @response.body, "sharer" # owner name shown
  end

  test "does not expose the owner's access token or a save form" do
    get shared_quiniela_path(token: @quiniela.share_token)
    assert_not_includes @response.body, @owner.access_token
    assert_select "input[type=submit]", false
  end

  test "an unknown token returns 404" do
    get shared_quiniela_path(token: "does-not-exist")
    assert_response :not_found
  end
end
