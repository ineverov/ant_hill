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
      @prior = config.init_time - Time.now
      # Add colony priority
      @prior += colony.get_priority
    end

    # Cache of creeps priorities
    def priority_cache(creep)
      @cached_priorities[creep] ||= creep.priority(self)
    end

    # Delete priority cache for specified creep
    # +creep+:: +Creep+ for which delete cache
    def delete_cache_for_creep(creep)
      @cached_priorities.delete(creep)
    end

    # Deelte all priprities cahce
    def delete_cache
      @cached_priorities = {}
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
    def from_hash(data)
      @type = data[:type]
      @status = data[:status]
      @executeion_status = data[:executeion_status]
      @prior = data[:prior]
      @output = data[:output]
    end

    # Convert Ant to hash
    def to_hash
      {
        :type => @type,
        :params => diff_with_colony,
        :status => @status,
        :execution_status => @execution_status,
        :prior => @prior,
        :output => @output
      }
    end

    # Re-process current ant
    def return_to_queue(queen = Queen.queen)
      queen.add_ants([self])
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

    # Finish ant processing
    def finish
      change_status(:finished)
      colony.colony_ant_finished
    end

    # Check if ant had been finished
    def finished?
      status == :finished
    end
  end
end
