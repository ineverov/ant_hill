module AntHill
  class Ant
    attr_reader :type, :params, :colony, :status, :config
    attr_accessor :execution_status, :runner, :prior, :output
    include DRbUndumped
    def initialize(params, colony, config = Configuration.config)
      @colony = colony
      @config = config
      @output = ''
      @params = colony.params.merge(params)

      @status = :not_started
      @execution_status = :queued
      @type = colony.type
      @prior = config.init_time - Time.now
      @prior += colony.get_priority
    end

    def to_s
      @colony.ant_to_s(self)
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
