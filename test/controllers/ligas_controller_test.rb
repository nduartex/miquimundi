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

  test "a non-member cannot leave (no false success)" do
    liga = create_liga
    sign_in(@friend) # not a member
    assert_no_difference "LigaMembership.count" do
      delete leave_liga_path(liga)
    end
    assert_redirected_to ligas_path
    assert_equal "No perteneces a esta liga.", flash[:alert]
  end

  test "creating with an invalid cupo leaves no orphan liga" do
    sign_in(@creator)
    assert_no_difference [ "Liga.count", "LigaMembership.count" ] do
      post ligas_path, params: { liga: { name: "Mala", max_players: 999 } }
    end
    assert_response :unprocessable_entity
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
    # The leaderboard controller highlights the signed-in user's own row.
    assert_match "data-controller=\"leaderboard\"", response.body
    assert_match "data-leaderboard-me-value=\"#{@creator.id}\"", response.body
  end

  # Prize -----------------------------------------------------------------

  def finish_tournament!
    @tournament.matches.create!(phase: "final", status: "finished", home_goals: 2, away_goals: 1)
  end

  test "creating a liga con premio stores the pot" do
    sign_in(@creator)
    post ligas_path, params: { liga: { name: "Con premio", max_players: 8, has_prize: "1", prize_pot: "500000" } }
    liga = Liga.last
    assert liga.has_prize?
    assert_equal 500_000, liga.prize_pot
  end

  test "creating con premio with an invalid pot is rejected" do
    sign_in(@creator)
    assert_no_difference "Liga.count" do
      post ligas_path, params: { liga: { name: "Mal premio", max_players: 8, has_prize: "1", prize_pot: "0" } }
    end
    assert_response :unprocessable_entity
  end

  test "creating sin premio ignores any pot sent" do
    sign_in(@creator)
    post ligas_path, params: { liga: { name: "Sin premio", max_players: 8, has_prize: "0", prize_pot: "500000" } }
    liga = Liga.last
    assert_not liga.has_prize?
    assert_nil liga.prize_pot
  end

  test "the creator can edit the prize" do
    liga = create_liga(name: "Editable")
    sign_in(@creator)
    patch liga_path(liga), params: { liga: { name: "Editable", max_players: 10, has_prize: "1", prize_pot: "300000" } }
    assert liga.reload.has_prize?
    assert_equal 300_000, liga.prize_pot
  end

  test "prize changes are blocked once the tournament finished (other fields still edit)" do
    liga = Liga.create!(name: "Premiada", max_players: 10, creator: @creator, tournament: @tournament,
                        has_prize: true, prize_pot: 500_000)
    liga.memberships.create!(user: @creator)
    finish_tournament!
    sign_in(@creator)

    patch liga_path(liga), params: { liga: { name: "Nuevo nombre", max_players: 10, has_prize: "0", prize_pot: "1" } }
    liga.reload
    assert liga.has_prize?, "the prize must not change after the tournament finished"
    assert_equal 500_000, liga.prize_pot
    assert_equal "Nuevo nombre", liga.name, "non-prize fields stay editable"
  end

  test "the prize section is provisional while the tournament is not finished" do
    liga = Liga.create!(name: "Pozo", max_players: 10, creator: @creator, tournament: @tournament,
                        has_prize: true, prize_pot: 500_000)
    liga.memberships.create!(user: @creator)
    sign_in(@creator)
    get liga_path(liga)
    assert_response :success
    assert_match(/Premio/, response.body)
    assert_match(/Pozo total/, response.body)
    assert_match(/Provisional/, response.body)
  end

  test "the prize section names the winner and the transfer once finished" do
    Quiniela.create!(user: @creator, tournament: @tournament, total_points: 50)
    Quiniela.create!(user: @friend, tournament: @tournament, total_points: 20)
    liga = Liga.create!(name: "Pozo", max_players: 10, creator: @creator, tournament: @tournament,
                        has_prize: true, prize_pot: 500_000)
    liga.memberships.create!(user: @creator)
    liga.memberships.create!(user: @friend)
    finish_tournament!
    sign_in(@creator)
    get liga_path(liga)
    assert_response :success
    assert_match(/Ganador/, response.body)
    assert_match "Cris", response.body          # creator leads with 50 pts
    assert_match(/transfiere/, response.body)
  end

  test "requires login" do
    get ligas_path
    assert_redirected_to new_session_path
  end
end
