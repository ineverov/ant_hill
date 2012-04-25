module AntHill
  class AntColony
    attr_accessor :params
    attr_reader :logger, :ants

    def initialize(params={}, config = Configuration.config )
      @params = params
      @config = config
      @logger = Log.logger_for(:ant_colony, config)
      @ants = []
    end

    def creep_modifier_class
      @creep_modifier_class ||= @config.creep_modifier_class(type)
      return @creep_modifier_class if @creep_modifier_class
      logger.error "Colony will die without creep modifier ;("
    end


    def spoiled?
      !@creep_modifier
    end

    def get_ants
      ant_larvas = search_ants(params)
      @ants = ant_larvas.collect{|larva|
        Ant.new(larva, self)
      }
      after_search
      @ants
    rescue Exception => e
      logger.error "Error while processing search ants for colony\n#{e}\n#{e.backtrace}"
    end

    def is_it_me?(params)
      params.all? do |key, value|
        @params[key] == value
      end
    end

    def not_finished
      ants.select{|ant|  ant.finished? }
    end

    # Can be redefined in child class
    def search_ants(params)
      []
    end
    
    def type
      @params['type']
    end

    def after_search
    end

    def ant_started(ant)
      ant.change_status :started
    end

    def ant_finished(ant)
      ant.change_status :finished
    end
    
    def after_colony
    end
  end
end
