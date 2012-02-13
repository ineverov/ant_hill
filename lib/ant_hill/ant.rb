module AntHill
  class Ant
    attr_reader :config, :type, :params
    def initialize(name, colony,  params={}, config=Configuration.config)
      @name = name

      @colony = colony

      @params = colony.params.merge(params)

      @config = config

      @type = colony.colony_type
      @priority = @config.init_time - Time.now
    end

    def matches?(params)
      @params.all? do |param,value|
        param_matches?(param, params[param])
      end
    end

    def param_matches?(param, value)
      matcher = config.matcher(@type)
      matcher.match(param, @params[param], value)
    end

    def priority(params, setupper = @config.setupper)
      priority = @priority
      @params.each{|param,value|
        unless param_matches?(param, params[param])
          priority -= setupper.change_time_for_param(param)
        end
      }
      priority
    end
  end
end
