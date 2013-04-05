module AntHill
  class AntColony
    attr_accessor :params
    attr_reader :logger, :ants
    include DRbUndumped
    def initialize(params={}, config = Configuration.config )
      @params = params
      @config = config
      @logger = Log.logger_for(:ant_colony, config)
      @ants = []
      @started = false
    end

    def from_hash(hash = nil)
      if hash
        @started = hash[:started]
        @params = hash[:params]
        @ants = hash[:ants].collect{|ant_data|
          ant = Ant.new(ant_data[:params], self)
          ant.from_hash(ant_data)
          ant
        }
      end
    end

    def to_hash(include_finished = false)
      _ants = @ants
      _ants = @ants.select{|a| !a.finished?} unless include_finished
      {
        :id => object_id,
        :started => @started,
        :params => @params,
        :ants => _ants.collect{|a| a.to_hash}
      }
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
      @ants = []
      ant_larvas = search_ants(params)
      @ants = ant_larvas.collect{|larva|
        Ant.new(larva, self)
      }
      after_search
      @ants
    rescue => e
      logger.error "Error while processing search ants for colony\n#{e}\n#{e.backtrace}"
    ensure
      # FIXME: Trigger colony finished if no ants were found
      colony_ant_finished
    end

    def is_it_me?(params)
      params.all? do |key, value|
        @params[key] == value
      end
    end

    def not_finished
      ants.select{|ant|  ant.finished? }
    end

    def finished?
      ants.all?{ |a| a.finished? } || ants.empty?
    end

    def logger
      Log.logger_for :ant_colony
    end

    # FIXME: Dont require any arguments
    def colony_ant_started
      unless @started
        @started = true
        begin 
          colony_started
        rescue => e
          logger.error "There was an error processing colony_started method for #{self.class}: #{e}\n#{e.backtrace}"
        end
      end
      @started ||= true
    end

    # FIXME: Dont require any arguments
    def colony_ant_finished
      if finished?
        begin 
          colony_finished
        rescue => e
          logger.error "There was an error processing colony_finished method for #{self.class}: #{e}\n#{e.backtrace}"
        ensure 
          Queen.queen.kill_colony(self)
        end
      end
    end

    def get_priority
      pr = 0
      begin
        pr = priority
      rescue => e
        logger.error "There was an error processing priority method for #{self.class}: #{e}\n#{e.backtrace}"
      ensure
        return pr
      end
    end
    
    def change_time_for_param(param)
      creep_modifier_class.change_time_for_param(param)
    end

    def kill
      ants.each do |ant|
        ant.change_status(:finished) if ant.status == :not_started
      end
    end

    # Can be redefined in child class
    def search_ants(params)
      []
    end

    def priority
      0
    end

    def ant_to_s(ant)
      ant.params.inspect
    end
    
    def type
      @params['type']
    end

    def colony_started
    end

    def colony_finished
    end
    
    def after_search
    end
  end
end
