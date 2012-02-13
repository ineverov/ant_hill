module AntHill
  class AntRunner < ConfigurableInterface
    @config_key = 'ant_runner_class'
    def run(ant)
      raise "Redefine in child"
    end

  end

end
