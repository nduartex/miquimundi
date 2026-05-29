module Results
  class BaseProvider
    def initialize(tournament, data = nil)
      @tournament = tournament
      @data = data
    end

    # Subclasses implement #apply! to write real results into the DB.
    def apply!
      raise NotImplementedError
    end
  end
end
