module AntHill
  class Ant
    attr_reader :type, :params, :colony, :status
    attr_accessor :execution_status
    def initialize(params, colony, config = Configuration.config)
      @colony = colony

      @params = colony.params.merge(params)

      @status = :not_started
      @execution_status = nil
      @type = colony.type
      @priority = config.init_time - Time.now
    end

    def to_s
      params.inspect
    end

    def priority(creep_params)
      priority = @priority
      creep_modifier = colony.creep_modifier_class.new
      params.each{|param,value|
        unless value == creep_params[param]
          priority -= creep_modifier.change_time_for_param(param)
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
