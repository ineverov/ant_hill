module AntHill
  class Creep
    def initialize(queen=Queen.queen, config=Configuration.config)
      @config = config
      @queen = queen
      @current_configuration = {}
    end
    
    def require_ant
      while Queen.locked?
        sleep 1
      end
      ant = @queen.find_ant(@current_configuration)
    end

    def setup_and_process_ant(ant)
      puts "****"
      puts ant.class
      puts "****"
      setup_params = find_diff(ant)
      setup(setup_params, ant.type)
      run(ant)
    end

    def find_diff(ant)
      diff = {}
      config = ant.params
      type = ant.type
      matcher = @config.matcher(type)

      config.each_key{|k|
        diff[k] = config[k] unless matcher.match(k, config[k], @current_configuration[k])
      }
    end

    def setup(params, type)
      setupper = @config.setupper(type)
      setupper.setup(params)
      params.each{|param, value|
        @current_configuration[param] = value
      }
    end

    def configure(hill_configuration)
      @hill_cfg = hill_configuration
    end

    def to_s
      @hill_cfg['host']
    end

    def service
      while true
        ant = self.require_ant
        if ant
          setup_and_process_ant(ant)
        else
          puts "#{self.to_s} is waiting ..." 
          sleep @config.sleep_interval
        end
      end
    end

    def run(ant)
      puts "Processing ant #{ant}"
      runner = @config.runner(ant.type)
      runner.run(ant)
    end
  end
end

