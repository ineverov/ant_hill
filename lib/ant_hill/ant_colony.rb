module AntHill
  class AntColony
    attr_accessor :params

    def initialize(params={}, type = nil, config = Configuration.config)
      @finder = config.finder(type)
      @params = params
      @type = type
    end

    def get_ants
      @finder.find_ants(params, self)
    end

    def colony_type
      @type
    end
  end
end
