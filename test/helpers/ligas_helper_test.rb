require "test_helper"

class LigasHelperTest < ActionView::TestCase
  # Metadata uses string keys on purpose: that is how jsonb comes back from the
  # database, and the helper must read it that way.
  def activity(action, metadata = {})
    LigaActivity.new(action: action, metadata: { "actor_name" => "Cris" }.merge(metadata))
  end

  test "liga_activity_text builds the Spanish sentence for each action" do
    assert_equal "Cris creó la liga", liga_activity_text(activity("created"))
    assert_equal "Cris se unió a la liga", liga_activity_text(activity("joined"))
    assert_equal "Cris salió de la liga", liga_activity_text(activity("left"))
    assert_equal "Cris expulsó a Fran", liga_activity_text(activity("expelled", "target_name" => "Fran"))
    assert_equal "Cris cambió el nombre de «Vieja» a «Nueva»",
                 liga_activity_text(activity("renamed", "from" => "Vieja", "to" => "Nueva"))
    assert_equal "Cris cambió el cupo de 10 a 6",
                 liga_activity_text(activity("cupo_changed", "from" => 10, "to" => 6))
    assert_equal "Cris activó el premio (pozo: 500.000)",
                 liga_activity_text(activity("prize_enabled", "pot" => 500_000))
    assert_equal "Cris desactivó el premio", liga_activity_text(activity("prize_disabled"))
    assert_equal "Cris cambió el pozo de 500.000 a 300.000",
                 liga_activity_text(activity("prize_pot_changed", "from" => 500_000, "to" => 300_000))
  end

  test "liga_activity_icon maps every action and falls back to clipboard-list" do
    LigaActivity::ACTIONS.each do |action|
      assert LigasHelper::LIGA_ACTIVITY_ICONS.key?(action), "missing icon for #{action}"
    end
    assert_equal "user-plus", liga_activity_icon(activity("joined"))
    assert_equal "clipboard-list", liga_activity_icon(LigaActivity.new(action: "unknown"))
  end
end
