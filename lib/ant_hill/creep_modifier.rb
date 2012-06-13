module AntHill
  class CreepModifier

    attr_reader :creep

    def initialize(creep)
      @creep = creep
    end

    def find_diff(ant)
      diff = {}
      ant_config = ant.params
      creep_config = creep.current_params

      ant_config.each_key{|k|
        diff[k] = ant_config[k] unless ant_config[k] == creep_config[k]
      }
      diff
    end
    
    def run_ant(ant)
      begin
        before_run(ant)
      rescue Exception => e
        logger.error "Error during run ant_started method: #{e} \n #{e.backtrace}"
      end
      begin
        run(ant)
      rescue Exception => e
        logger.error "Error during processing run method: #{e} \n #{e.backtrace}"
      ensure
        begin
          after_run(ant)
        rescue Exception => e
          logger.error "Error in ant_finished method: #{e} \n #{e.backtrace}"
        end
      end
    end


    def setup_ant(ant)
      ant.runner = creep
      ant.change_status(:setup)
      begin
        before_setup(ant)
      rescue Exception => e
        logger.error "Error during processing before_setup method: #{e} \n #{e.backtrace}"
      end
      result = nil
      begin 
        result = setup(ant)
      rescue Exception => e
        logger.error "Error during processing setup method: #{e} \n #{e.backtrace}"
      end
      begin
        after_setup(ant)
      rescue Exception => e
        logger.error "Error during processing after_setup method: #{e} \n #{e.backtrace}"
      end
      result
    end


    def logger
      creep.logger
    end

    # Can be redefined in child class
    def get_setup_time(ant, params)
      0
    end
    
    def get_run_time(ant)
      0
    end

    def before_run(ant)
    end

    def after_run(ant)
    end

    def before_setup(ant)
    end

    def after_setup(ant)
    end

    def setup_failed(ant)
    end

    def before_process(ant)
    end

    def after_process(ant)
    end

    def setup(ant)
      true
    end

    def run(ant)
    end

    def check(ant)
      true
    end

    def self.change_time_for_param(param)
      0
    end

  end

end
