module AntHill
  class Ant
    attr_reader :type, :colony, :status, :config
    attr_accessor :execution_status, :runner, :prior, :output
    include DRbUndumped
    def initialize(params, colony, config = Configuration.config)
      @colony = colony
      @config = config
      @output = ''
      @params = params

      @status = :not_started
      @execution_status = :queued
      @type = colony.type
      @prior = config.init_time - Time.now
      @prior += colony.get_priority
    end

    def params
      @colony.params.merge(@params)
    end

    def to_s
      @colony.ant_to_s(self)
    end

    def diff_with_colony
      colony_params = colony.params
      params.inject({}){ |res, kv|
        res[kv[0]] = kv[1] if colony_params[kv[0]] != kv[1]
        res
      }
    end

    def from_hash(data)
      @type = data[:type]
      @status = data[:status]
      @executeion_status = data[:executeion_status]
      @prior = data[:prior]
      @output = data[:output]
    end

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

    def priority(creep_params)
      priority = @prior
      params.each{|param,value|
        unless value == creep_params[param]
          priority -= colony.change_time_for_param(param)
        end
      }
      priority
    end

    def return_to_queue(queen = Queen.queen)
      queen.add_ants([self])
    end

    def change_status(status)
      @status = status
    end

    def logger
      colony.logger
    end

    def start
      change_status(:started)
      colony.colony_ant_started
    end

    def finish
      change_status(:finished)
      colony.colony_ant_finished
    end

    def finished?
      status == :finished
    end
  end
end
