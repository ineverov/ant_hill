module AntHill
  class CreepModifier

    attr_reader :creep

    def initialize(creep)
      @creep = creep
    end

    def find_diff(ant)
      diff = {}
      ant_config = ant.params
      creep_config = creep.current_params

      ant_config.each_key{|k|
        diff[k] = ant_config[k] unless ant_config[k] == creep_config[k]
      }
      diff
    end

    # Can be redefined in child class
    def setup(ant)
    end

    def run(ant)
    end

    def check(ant)
    end

  end

end
