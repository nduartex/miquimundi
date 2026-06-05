require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid username passes" do
    assert User.new(username: "martin_10").valid?
  end

  test "enforces 5-20 length and allows special symbols" do
    assert_not User.new(username: "abcd").valid?, "4 chars should be rejected"
    assert User.new(username: "abcde").valid?, "5 chars should pass"
    assert User.new(username: "co$ar!_#-").valid?, "special symbols should pass"
    assert_not User.new(username: "a" * 21).valid?, "21 chars should be rejected"
  end

  test "rejects HTML/quote/space characters" do
    [ "user<x>", "a'b\"c", "has space", "a/b\\c" ].each do |bad|
      assert_not User.new(username: bad).valid?, "#{bad.inspect} should be rejected"
    end
  end

  test "strips control and zero-width characters before validating" do
    user = User.new(username: "mar​tin‮10") # zero-width space + RTL override
    user.valid?
    assert_equal "martin10", user.username
  end

  test "rejects offensive usernames including leetspeak and separator evasion" do
    %w[cabron c4br0n c.a.b.r.o.n caaaabron elputo putos f_u_c_k hijodeputa].each do |name|
      user = User.new(username: name)
      assert_not user.valid?, "expected #{name.inspect} to be rejected"
      assert_includes user.errors[:username], "contiene lenguaje no permitido, elige otro"
    end
  end

  test "allows clean names that merely contain a rude substring" do
    %w[computadora recoger calculo diputado masculino].each do |name|
      assert User.new(username: name).valid?, "expected #{name.inspect} to be allowed"
    end
  end

  test "requires a unique username (case-insensitive)" do
    User.create!(username: "Martin5")
    assert_not User.new(username: "martin5").valid?
  end

  test "generates a unique access token on create" do
    a = User.create!(username: "tokenuser")
    b = User.create!(username: "tokenuser2")
    assert a.access_token.present?
    assert_not_equal a.access_token, b.access_token
  end

  test "display_name falls back to username" do
    assert_equal "neoone", User.new(username: "neoone").display_name
    assert_equal "Neo R", User.new(username: "neoone", name: "Neo R").display_name
  end

  # PIN -------------------------------------------------------------------

  test "a user starts without a PIN" do
    assert_not User.new(username: "nopinuser").has_pin?
  end

  test "saving without touching the PIN is allowed" do
    assert User.new(username: "skippin").valid?
  end

  test "a valid 8-digit PIN can be set and authenticated" do
    user = User.create!(username: "pinuser", pin: "12345678", pin_confirmation: "12345678")
    assert user.has_pin?
    assert user.authenticate_pin("12345678")
    assert_not user.authenticate_pin("87654321")
  end

  test "the PIN is stored hashed, never in plain text" do
    user = User.create!(username: "hashpin", pin: "12345678", pin_confirmation: "12345678")
    assert_not_equal "12345678", user.pin_digest
    assert user.pin_digest.present?
  end

  test "rejects PINs that are not exactly 8 digits" do
    [ "1234567", "123456789", "1234abcd", "abcdefgh", "1234 567" ].each do |bad|
      user = User.new(username: "badpin", pin: bad, pin_confirmation: bad)
      assert_not user.valid?, "#{bad.inspect} should be rejected"
      assert_includes user.errors[:pin], "debe ser de 8 dígitos numéricos"
    end
  end

  test "rejects a PIN whose confirmation does not match" do
    user = User.new(username: "mismatch", pin: "12345678", pin_confirmation: "00000000")
    assert_not user.valid?
  end

  test "requires a confirmation when setting a PIN" do
    user = User.new(username: "noconfirm", pin: "12345678")
    assert_not user.valid?
    assert_includes user.errors[:pin_confirmation], "confirma tu PIN"
  end
end
