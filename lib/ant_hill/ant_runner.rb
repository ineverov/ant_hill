module AntHill
  class AntRunner < ConfigurableInterface
    @config_key = 'ant_runner_class'
    def run(ant, creep)
      raise "Redefine in child"
    end
  end

end
