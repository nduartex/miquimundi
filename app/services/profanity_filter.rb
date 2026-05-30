# Blocks usernames containing offensive words. The username field allows digits
# and special characters, so a naive blocklist is trivially bypassed
# (c4br0n, c.a.b.r.o.n, caaabron, el-puto). We fold leetspeak and accents, drop
# non-letters, and collapse repeats, then match on word ROOTS.
#
# Two tiers, to stay evasion-resistant WITHOUT the Scunthorpe problem (clean
# names that merely contain a short rude substring — cockburn, computadora,
# recoger, calculo):
#   * SUBSTRING_ROOTS — long (>=6); appearing inside a word is almost always
#     intentional, so matched anywhere.
#   * WORD_ROOTS — short (<=5); matched only as a standalone token or
#     root+suffix (optionally after a common article prefix like "el"), so
#     "puto"/"putos"/"elputo" are caught but "computadora"/"recoger" are not.
module ProfanityFilter
  module_function

  LEET = {
    "0" => "o", "1" => "i", "3" => "e", "4" => "a", "5" => "s",
    "6" => "g", "7" => "t", "8" => "b", "9" => "g", "@" => "a",
    "$" => "s", "!" => "i", "+" => "t"
  }.freeze

  SUBSTRING_ROOTS = %w[
    cabron cabrona pendejo pendeja chinga chingada chingar chingu mierda culiao
    culiado conchatumadre conchetumare conchesumadre gonorrea pirobo malparido
    hijueputa hijoputa hijodeputa putamadre maricon marica gilipollas cojones
    carajo cipote estupido estupida imbecil idiota subnormal retrasado mongolo
    fucker motherfucker fuckin fucking asshole bastard bitch nigger nigga
    faggot retard wanker pussy whore hitler
  ].freeze

  WORD_ROOTS = %w[
    puta puto cono polla verga zorra perra culo culero mamon joto pajero marik
    ctm hdp hpta sexo pene porn xxx fuck fuk fck shit dick dik cock cunt fag
    twat wank slut nazi kkk cono
  ].freeze

  SUFFIX = /(s|es|as|os|a|o|on|ona|azo|aza|ote|ito|ita|tos|das)?/
  PREFIXES = %w[el la lo los las un una unos unas tu mi su soy es son ser].freeze

  def offensive?(name)
    collapsed = normalize(name)
    return false if collapsed.blank?

    return true if SUBSTRING_ROOTS.any? { |r| collapsed.include?(r) }

    candidates = tokens(name)
    candidates << collapsed
    PREFIXES.each { |p| candidates << collapsed.delete_prefix(p) if collapsed.start_with?(p) }
    candidates.uniq!

    WORD_ROOTS.any? do |r|
      re = /\A#{Regexp.escape(r)}#{SUFFIX}\z/
      candidates.any? { |c| re.match?(c) }
    end
  end

  # Fold accents+leet, drop non-letters, collapse ALL repeats to one letter
  # ("caaaabron" -> "cabron"). Roots have no doubled letters, so this is safe.
  def normalize(name)
    fold(name).gsub(/[^a-z]/, "").gsub(/(.)\1+/, '\1')
  end

  def tokens(name)
    fold(name).split(/[^a-z]+/).reject(&:blank?).map { |t| t.gsub(/(.)\1+/, '\1') }
  end

  # Decompose accents (é -> e + combining mark) and fold leetspeak, staying in
  # UTF-8 throughout. Combining marks and any other non a-z are dropped later by
  # normalize/tokens via the /[^a-z]/ filter, so no risky .encode is needed.
  def fold(name)
    s = name.to_s.unicode_normalize(:nfkd).downcase
    s.chars.map { |c| LEET[c] || c }.join
  end
end
