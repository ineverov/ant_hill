module AntHill

  # Object that find Ants and store them 
  class AntColony
    # Attribute accessors
    # +params+:: +AntColony+ params
    # +ants+:: array of +Ant+'s for this colony
    # +status+:: colony status
    attr_accessor :params, :ants, :status
    
    # Attribute reader
    # +logger+:: logger for AntColony
    attr_reader :logger
    
    include DRbUndumped

    # Initailize of +AntColony+
    # +params+:: params for colony
    # [+config+]:: configuration
    def initialize(params={}, config = Configuration.config )
      @params = params
      @config = config
      @logger = Log.logger_for(:ant_colony, config)
      @created_at = Time.now
      @ants = []
      @started = false
    end

    # Create +AntColony+ from hash
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

    # Convert +AntColony+ into hash
    # +include_finished+:: include in hash finished +Ant+'s (default: false)
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

    # Ger +CreepModifier+ class for +AntColony+ type
    def creep_modifier_class
      @creep_modifier_class ||= @config.creep_modifier_class(type)
      return @creep_modifier_class if @creep_modifier_class
      logger.error "Colony will die without creep modifier ;("
    end

    # Params will be inherited by +Ant+s
    def params_for_ant
      params.inject({}) do |hash,kv| 
        if !inherited_params || inherited_params.include?(kv[0])
          hash[kv[0]]=kv[1]
        end
        hash
      end
    end

    # return true if no +CreepModifier+ found for colony
    def spoiled?
      !@creep_modifier
    end

    # Find ants for colony params
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
      # Retry 3 times, esle return []
      retries ||= 0
      retries += 1
      retry if retries < 3
      []
    ensure
      # FIXME: Trigger colony finished if no ants were found
      colony_ant_finished
    end

    # Check if colony matches params
    # +params+:: params to match
    def is_it_me?(params)
      params.all? do |key, value|
        @params[key] == value
      end
    end

    # Return list of not finished ants
    def not_finished
      ants.select{|ant|  ant.finished? }
    end

    # Check if colony had been finished
    def finished?
      ants.all?{ |a| a.finished? } || ants.empty?
    end

    # retunr true if colony was killed
    def killed?
      @status == :killed
    end

    # Return logger
    def logger
      Log.logger_for :ant_colony
    end

    # Trigger colony_started if not already started
    def colony_ant_started
      # FIXME: Dont require any arguments
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

    # Trigger colony_finished if all ants are finished
    def colony_ant_finished
      # FIXME: Dont require any arguments
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
    
    # Colony type
    def type
      @params['type']
    end

    # Calculate priority for colony
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

    # Mark all unprocessed ants as finished
    def kill
      @status = :killed
      ants.each do |ant|
        ant.change_status(:finished) if ant.status == :not_started
      end
    end

    # Return array of params hashes for ants
    # default: empty array
    # Should be redefined in child class
    def search_ants(params)
      []
    end

    # Return AntColony priority
    # default: -created_at.to_int
    # Can be redefined in child class
    def priority
      -created_at.to_i
    end

    # Convert ant to string
    # Can be redefined in child class
    def ant_to_s(ant)
      ant.params.inspect
    end
    
    # Actions to perform if colony started 
    # Can be redefined in child class
    def colony_started
    end

    # Actions to perform if colony finished
    # Can be redefined in child class
    def colony_finished
    end
    
    # Actions to perform after ants were found
    # Can be redefined in child class
    def after_search
    end

    # List of params Ants will inherit
    # Can be redefined in child class
    def inherited_params
    end
  end
end
