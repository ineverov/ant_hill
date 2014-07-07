module AntHill

  # Base class for setup/run logic
  # Childrens should implement specific logic for particular ant type
  class CreepModifier

    # Creep object
    attr_reader :creep

    include DRbUndumped

    # Initialize 
    # +creep+:: Creep which we gonna change
    def initialize(creep)
      @creep = creep
    end

    # Find diff between current params of creep and ant params
    def find_diff(ant)
      diff = {}
      ant_config = ant.params
      creep_config = creep.current_params

      ant_config.each_key{|k|
        diff[k] = ant_config[k] unless ant_config[k] == creep_config[k]
      }
      diff
    end
    
    # Run ant
    # +ant+:: ant to run
    def run_ant(ant)
      begin
        before_run(ant)
      rescue => e
        logger.error "Error during run ant_started method: #{e} \n #{e.backtrace}"
      end
      begin
        out = run(ant)
        ant.output = out
      rescue => e
        logger.error "Error during processing run method: #{e} \n #{e.backtrace}"
      ensure
        begin
          after_run(ant)
        rescue => e
          logger.error "Error in ant_finished method: #{e} \n #{e.backtrace}"
        end
      end
    end

    # Setup ant for running
    # +ant+:: Ant to setup
    def setup_ant(ant)
      ant.runner = creep
      ant.change_status(:setup)
      begin
        before_setup(ant)
      rescue => e
        logger.error "Error during processing before_setup method: #{e} \n #{e.backtrace}"
      end
      result = nil
      begin 
        result = setup(ant)
      rescue => e
        logger.error "Error during processing setup method: #{e} \n #{e.backtrace}"
      end
      begin
        after_setup(ant)
      rescue => e
        logger.error "Error during processing after_setup method: #{e} \n #{e.backtrace}"
      end
      result
    end

    # Logger for creep
    def logger
      creep.logger
    end

    # Return calculated setup time for ant
    # +ant+:: ant to setup
    # Can be redefined in child class
    def get_setup_time(ant)
    end
   
    # Return calculated run time for ant
    # +ant+:: ant to run
    # Can be redefined in child class
    def get_run_time(ant)
    end

    # Before run hook 
    # +ant+:: ant to run
    def before_run(ant)
    end

    # After run hook 
    # +ant+:: ant was ran
    def after_run(ant)
    end

    # Before setup hook 
    # +ant+:: ant to setup
    def before_setup(ant)
    end

    # After setup hook 
    # +ant+:: ant was set up
    def after_setup(ant)
    end

    # Setup failed hook 
    # +ant+:: ant for wich setup failed
    def setup_failed(ant)
    end

    # Before process hook 
    # +ant+:: ant to be processed
    def before_process(ant)
    end

    # After process hook 
    # +ant+:: ant was processed
    def after_process(ant)
    end

    # Setup implementation
    # +ant+:: ant to set up
    def setup(ant)
      true
    end

    # Run implementation
    # +ant+:: ant to run
    def run(ant)
    end

    # Check node is set up 
    # +ant+:: ant to check
    def check(ant)
      true
    end

    # Params from ant to be coppied after setup
    def creep_params
    end
  end

end
