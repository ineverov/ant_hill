module AntHill
  # Instance of job to process
  class Ant
    # Attribute readers
    # +type+:: +AntColony+ type
    # +colony+:: +AntColony+
    # +status+:: ant status
    # +config+:: configuration
    # +params+:: +AntColony+ params_for_ant and ant specific params
    attr_reader :type, :colony, :status, :config, :params
    # Attribute accessors
    # +execution_status+:: status of run in +CreepModifier+
    # +runner+:: +Creep+ there ant is processing or was processed
    # +prior+:: base priority of ant
    # +output+:: return value of run method of +CreepModifier+
    attr_accessor :execution_status, :runner, :prior, :output
    include DRbUndumped

    # Initialize method
    # +params+:: +Ant+ specific params
    # +colony+:: +AntColony+ which +Ant+ belongs to
    # [+config+]:: configuration
    def initialize(params, colony, config = Configuration.config)
      @colony = colony
      @config = config
      @output = ''
      # Ant params are colony params_for_ant + specific ant params
      @params = @colony.params_for_ant.merge(params)

      @status = :not_started
      @execution_status = :queued
      # Cache priorities for each creep for faster access
      @cached_priorities = {}
      # Ant type is colony type
      @type = colony.type
      # Set initial priority to queen start time - Time.now so ants created later will have lower priority
      @prior = (config.init_time - Time.now).to_i
      # Add colony priority
      @prior += colony.get_priority
      @priority_cache_mutex = Mutex.new
    end

    def marked?
      @marked
    end

    def mark
      @marked = true
    end

    def unmark
      @marked = false
    end

    # Cache of creeps priorities
    def priority_cache(creep)
      @priority_cache_mutex.synchronize do 
        id = creep.object_id
        @cached_priorities[id] ||= creep.priority(self)
      end
    end

    # Delete priority cache for specified creep
    # +creep+:: +Creep+ for which delete cache
    def delete_cache_for_creep(creep)
      @priority_cache_mutex.synchronize do
        @cached_priorities.delete(creep.object_id)
      end
    end

    # Deelte all priprities cahce
    def delete_cache
      @priority_cache_mutex.synchronize do
        @cached_priorities = {}
      end
    end

    # Create string representation of Ant
    def to_s
      @colony.ant_to_s(self)
    end

    # Show diff between ant params and ant colony params
    def diff_with_colony
      colony_params = colony.params
      params.inject({}){ |res, kv|
        res[kv[0]] = kv[1] if colony_params[kv[0]] != kv[1]
        res
      }
    end
    
    # Create Ant from hash
    def from_hash(codder)
      @type = codder['type']
      @status = codder['status']
      @execution_status = codder['execution_status']
      @prior = codder['prior']
      @output = codder['output']
      @params = @colony.params_for_ant.merge(codder['params'])
    end

    # Convert Ant to hash
    def to_hash
      {}.tap{|codder|
        codder['type'] = @type
        codder['params'] = diff_with_colony
        codder['status'] = @status
        codder['execution_status'] = @execution_status
        codder['prior'] = @prior
        codder['output'] = @output
      }
    end
    # Re-process current ant
    def return_to_queue
      unmark
    end

    # Update status for ant
    # +status+:: new status
    def change_status(status)
      @status = status
    end

    # return logger for ant_colony
    def logger
      colony.logger
    end

    # Start ant processing
    def start
      change_status(:started)
      colony.colony_ant_started
    end

    def kill
      mark unless marked?
      finish unless status == :finished
    end

    # Finish ant processing
    def finish
      change_status(:finished)
      colony.colony_ant_finished
    end

    # Check if ant had been finished
    def finished?
      marked? && (status == :finished)
    end
  end
end
