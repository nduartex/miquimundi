require "test_helper"

class QuinielaMailerTest < ActionMailer::TestCase
  test "confirmation is addressed to the user with subject" do
    tournament = Tournament.create!(name: "WC", year: 2026)
    user = User.create!(email: "p@x.com", name: "Pancho")
    quiniela = Quiniela.create!(user: user, tournament: tournament)
    mail = QuinielaMailer.confirmation(quiniela)
    assert_equal ["p@x.com"], mail.to
    assert_match "Quiniela", mail.subject
    assert_match "Pancho", mail.body.encoded
  end
end
