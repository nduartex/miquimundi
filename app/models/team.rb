class Team < ApplicationRecord
  belongs_to :group
  has_many :players, dependent: :destroy

  validates :name, presence: true

  # FIFA 3-letter code -> ISO 3166-1 code used by flagcdn.com (for flag images).
  # Emoji flags don't render on Windows, so we serve real flag images instead.
  ISO2 = {
    "MEX" => "mx", "RSA" => "za", "KOR" => "kr", "CZE" => "cz",
    "CAN" => "ca", "BIH" => "ba", "QAT" => "qa", "SUI" => "ch",
    "BRA" => "br", "MAR" => "ma", "HAI" => "ht", "SCO" => "gb-sct",
    "USA" => "us", "PAR" => "py", "AUS" => "au", "TUR" => "tr",
    "GER" => "de", "CUW" => "cw", "CIV" => "ci", "ECU" => "ec",
    "NED" => "nl", "JPN" => "jp", "SWE" => "se", "TUN" => "tn",
    "BEL" => "be", "EGY" => "eg", "IRN" => "ir", "NZL" => "nz",
    "ESP" => "es", "CPV" => "cv", "KSA" => "sa", "URU" => "uy",
    "FRA" => "fr", "SEN" => "sn", "IRQ" => "iq", "NOR" => "no",
    "ARG" => "ar", "ALG" => "dz", "AUT" => "at", "JOR" => "jo",
    "POR" => "pt", "COD" => "cd", "UZB" => "uz", "COL" => "co",
    "ENG" => "gb-eng", "CRO" => "hr", "GHA" => "gh", "PAN" => "pa"
  }.freeze

  # Name first, flag on the right (emoji fallback for non-select contexts).
  def label
    [name, flag_emoji].compact.join("  ")
  end

  # Real flag image (SVG) URL, or nil when the code is unknown.
  def flag_url
    iso = ISO2[code]
    iso && "https://flagcdn.com/#{iso}.svg"
  end
end
