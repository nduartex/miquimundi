class GroupResult < ApplicationRecord
  belongs_to :group
  belongs_to :first_team, class_name: "Team"
  belongs_to :second_team, class_name: "Team"

  def qualified_team_ids
    [first_team_id, second_team_id]
  end
end
