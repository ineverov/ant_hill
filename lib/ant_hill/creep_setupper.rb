module AntHill
  class CreepSetupper < ConfigurableInterface
    @config_key = 'creep_setupper_class'
    def setup(creep, params)
      raise "Redefine in child"
    end
  end

end
