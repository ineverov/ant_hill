module AntHill
  class CreepModifier

    attr_reader :creep

    def initialize(creep)
      @creep = creep
    end

    def find_diff(ant)
      diff = {}
      config = ant.params
      type = ant.type

      config.each_key{|k|
        diff[k] = config[k] unless config[k] == @current_configuration[k]
      }
      diff
    end

    # Can be redefined in child class
    def setup
    end

    def run
    end

    def check
    end

  end

end
