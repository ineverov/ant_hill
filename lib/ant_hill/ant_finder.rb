module AntHill
  class AntColonyFinder < ConfigurableInterface
    @config_key = 'ant_colony_finder_class'
    def find_ants(params, colony)
      ant_larvas = search_ants(params)
      ant_larvas.collect{|larva|
        Ant.new(larva[0], colony, larva[1])
      }
    end

    def search_ants(params)
      raise "Redefine in child"
    end
  end

end
