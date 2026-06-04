require "test_helper"

class LigasControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @creator = User.create!(username: "creator_fc", name: "Cris")
    @friend = User.create!(username: "friend_fc", name: "Fran")
  end

  def sign_in(user)
    get restore_path(token: user.access_token)
  end

  def create_liga(creator: @creator, max_players: 10, name: "Los amigos")
    liga = Liga.create!(name: name, max_players: max_players, creator: creator, tournament: @tournament)
    liga.memberships.create!(user: creator)
    liga
  end

  test "creating a liga makes the creator a member" do
    sign_in(@creator)
    assert_difference -> { Liga.count } => 1, -> { LigaMembership.count } => 1 do
      post ligas_path, params: { liga: { name: "Mi liga", max_players: 8 } }
    end
    liga = Liga.last
    assert_redirected_to liga_path(liga)
    assert liga.member?(@creator)
  end

  test "joining by code adds a membership" do
    liga = create_liga
    sign_in(@friend)
    assert_difference "LigaMembership.count", 1 do
      post join_ligas_path, params: { invite_code: liga.invite_code.downcase }
    end
    assert liga.member?(@friend)
    assert_redirected_to liga_path(liga)
  end

  test "joining with an invalid code is rejected" do
    sign_in(@friend)
    assert_no_difference "LigaMembership.count" do
      post join_ligas_path, params: { invite_code: "ZZZZZZ" }
    end
    assert_redirected_to ligas_path
    assert_equal "Código inválido.", flash[:alert]
  end

  test "joining twice is not allowed" do
    liga = create_liga
    liga.memberships.create!(user: @friend)
    sign_in(@friend)
    assert_no_difference "LigaMembership.count" do
      post join_ligas_path, params: { invite_code: liga.invite_code }
    end
  end

  test "joining a full liga is rejected" do
    liga = create_liga(max_players: 2) # creator + one more fills it
    liga.memberships.create!(user: User.create!(username: "filler_fc"))
    sign_in(@friend)
    assert_no_difference "LigaMembership.count" do
      post join_ligas_path, params: { invite_code: liga.invite_code }
    end
    assert_equal "La liga está completa.", flash[:alert]
  end

  test "a member can leave" do
    liga = create_liga
    liga.memberships.create!(user: @friend)
    sign_in(@friend)
    assert_difference "LigaMembership.count", -1 do
      delete leave_liga_path(liga)
    end
    assert_not liga.member?(@friend)
  end

  test "the creator cannot leave" do
    liga = create_liga
    sign_in(@creator)
    assert_no_difference "LigaMembership.count" do
      delete leave_liga_path(liga)
    end
    assert_redirected_to liga_path(liga)
  end

  test "the creator can expel a member" do
    liga = create_liga
    membership = liga.memberships.create!(user: @friend)
    sign_in(@creator)
    assert_difference "LigaMembership.count", -1 do
      delete liga_member_path(liga, membership)
    end
    assert_not liga.member?(@friend)
  end

  test "a non-creator cannot expel" do
    liga = create_liga
    membership = liga.memberships.create!(user: @friend)
    sign_in(@friend)
    assert_no_difference "LigaMembership.count" do
      delete liga_member_path(liga, membership)
    end
  end

  test "the creator can delete the liga only when alone" do
    liga = create_liga
    other_membership = liga.memberships.create!(user: @friend)
    sign_in(@creator)

    assert_no_difference "Liga.count" do
      delete liga_path(liga)
    end
    assert_redirected_to liga_path(liga)

    other_membership.destroy
    assert_difference "Liga.count", -1 do
      delete liga_path(liga)
    end
    assert_redirected_to ligas_path
  end

  test "index, new and edit render successfully" do
    liga = create_liga
    sign_in(@creator)
    get ligas_path
    assert_response :success
    get new_liga_path
    assert_response :success
    get edit_liga_path(liga)
    assert_response :success
  end

  test "show displays the invite code for copying" do
    liga = create_liga
    sign_in(@creator)
    get liga_path(liga)
    assert_response :success
    assert_match liga.invite_code, response.body
    assert_match "data-controller=\"clipboard\"", response.body
  end

  test "the creator can edit name and cupo" do
    liga = create_liga(max_players: 10)
    sign_in(@creator)
    patch liga_path(liga), params: { liga: { name: "Nuevo nombre", max_players: 6 } }
    assert_redirected_to liga_path(liga)
    liga.reload
    assert_equal "Nuevo nombre", liga.name
    assert_equal 6, liga.max_players
  end

  test "a non-creator cannot edit the liga" do
    liga = create_liga
    liga.memberships.create!(user: @friend)
    sign_in(@friend)
    get edit_liga_path(liga)
    assert_redirected_to liga_path(liga)
    patch liga_path(liga), params: { liga: { name: "Hackeada" } }
    assert_redirected_to liga_path(liga)
    assert_equal "Los amigos", liga.reload.name
  end

  test "cupo cannot be lowered below the current member count" do
    liga = create_liga(max_players: 10)
    liga.memberships.create!(user: @friend) # now 2 members
    sign_in(@creator)
    patch liga_path(liga), params: { liga: { max_players: 1 } }
    assert_response :unprocessable_entity
    assert_equal 10, liga.reload.max_players
  end

  test "cupo edit still respects the 2-50 hard limit" do
    liga = create_liga
    sign_in(@creator)
    patch liga_path(liga), params: { liga: { max_players: 51 } }
    assert_response :unprocessable_entity
    assert_equal 10, liga.reload.max_players
  end

  test "show is only visible to members" do
    liga = create_liga
    sign_in(@friend) # not a member
    get liga_path(liga)
    assert_redirected_to ligas_path

    liga.memberships.create!(user: @friend)
    get liga_path(liga)
    assert_response :success
  end

  test "liga ranking respects the global order filtered to members" do
    Quiniela.create!(user: @creator, tournament: @tournament, total_points: 20)
    Quiniela.create!(user: @friend, tournament: @tournament, total_points: 50)
    outsider = User.create!(username: "outsider_fc", name: "Out")
    Quiniela.create!(user: outsider, tournament: @tournament, total_points: 99)

    liga = create_liga
    liga.memberships.create!(user: @friend)
    sign_in(@creator)
    get liga_path(liga)
    assert_response :success
    assert_match "Fran", response.body
    assert_no_match "Out", response.body # outsider not in this liga
  end

  test "requires login" do
    get ligas_path
    assert_redirected_to new_session_path
  end
end
