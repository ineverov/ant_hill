module AntHill
  class Ant
    attr_reader :type, :params, :colony, :status, :config
    attr_accessor :execution_status
    def initialize(params, colony, config = Configuration.config)
      @colony = colony
      @config = config

      @params = colony.params.merge(params)

      @status = :not_started
      @execution_status = :queued
      @type = colony.type
      @priority = config.init_time - Time.now
    end

    def to_s
      params.inspect
    end

    def priority(creep_params)
      priority = @priority
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

    def finished?
      status == :finished
    end
  end
end
