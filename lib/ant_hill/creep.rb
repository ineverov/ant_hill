module AntHill
  # Node object
  class Creep

    # +host+:: hostname of creep
    # +user+:: username to connect
    # +password+:: password to connect
    # +status+:: status of creep
    # +processed+:: number of ants processed
    # +passed+:: number of successfully processed ants
    # +start_time+:: status time
    # +hill_cfg+:: creep configuration
    # +current_ant+:: currently processing ant
    attr_reader :host, :user, :password, :status, :processed, :passed, :start_time, :hill_cfg, :current_ant
    # +active+:: node activness
    # +custom_data+:: custom data hash
    # +force_priority+:: If true recalculate priority for this creep instaed of taking cahced values
    # +current_params+:: current creep configuration
    # +name+:: creep name
    attr_accessor :active, :custom_data, :force_priority, :current_params, :name
    include DRbUndumped

    #Initialize method
    #[+queen+]:: queen obeject
    #[+config+]:: configuration
    def initialize(queen=Queen.queen, config=Configuration.config)
      @config = config
      @queen = queen
      @current_params = {}
      @custom_data = {}
      @status = :wait
      @current_ant = nil
      @processed = 0
      @passed = 0
      @active = true
      @start_time = Time.now
      @force_priority = false
      @modifiers = {}
      @changed_params = []
    end

    #Find ant best matching current configuration based on priority
    def require_ant
      time = Time.now
      ant = @queen.find_ant(self)
      logger.debug "Find min ant took #{Time.now - time}"
      ant
    end

    # Return priority of ant for this creep
    # +ant+:: ant to calculate priority
    def priority(ant)
      mod = modifier(ant)
      ant.prior - mod.get_setup_time(ant)
    end

    # Initialize instance variables from hash
    # +hash+:: creep hash
    def from_hash(hash)
      @current_params = (hash[:current_parmas] || {})
      @custom_data = hash[:custom_data] || {}
      @status = hash[:status] || :wait
      @processed = hash[:processed] || 0
      @passed = hash[:passed] || 0
      @active = hash[:active].nil? ? true : hash[:active]
      @start_time = hash[:start_time] || Time.now
      @hill_cfg.merge!(hash[:hill_cfg] || {})
    end

    # Convert current creep to hash
    def to_hash
      {
        :id => object_id,
        :current_params => current_params,
        :custom_data => @custom_data,
        :status => @status,
        :processed => @processed,
        :passed => @passed,
        :active => @active,
        :start_time => @start_time,
        :hill_cfg => @hill_cfg
      }
    end

    # Return modifier object for ant
    # +ant+:: ant for which we need modifier
    def modifier(ant)
      @modifiers[ant.type] ||= ant.colony.creep_modifier_class.new(self)
    end

    # Do setup and run ant
    # +ant+:: ant to setup and run
    def setup_and_process_ant(ant)
      @current_ant = ant
      @modifier = modifier(ant)
      ant.start
      safe do
        before_process(ant)
        ok = setup(ant)
        if ok
          ant.params.each do |k,v|
            if !@modifier.creep_params || @modifier.creep_params.include?(k)
              if current_params[k] != v
                current_params[k]=v
                self.force_priority = true
              end
            end
          end
          run(ant)
        else
          setup_failed(ant)
          self.force_priority = true
        end
      end
      ant.finish
      safe{ after_process(ant) }
      if self.force_priority
        Queen.queen.reset_priority_for_creep(self)
        self.force_priority = false
      end
      @processed+=1
      @passed +=1 if @current_ant.execution_status.to_sym == :passed
      @current_ant = nil
    end

    # Before process hook
    # +ant+:: Ant object
    def before_process(ant)
      @modifier.before_process(ant)
    end

    # After process hook
    # +ant+:: Ant object
    def after_process(ant)
      @modifier.after_process(ant)
    end

    # Setup failed hook
    # +ant+:: Ant object
    def setup_failed(ant)
      @modifier.setup_failed(ant)
    end

    # Setup method
    # +ant+:: Ant object
    def setup(ant)
      timeout = 0
      timeout = @modifier.get_setup_time(ant)
      change_status(:setup)
      ok = false
      logger.debug "executing setup method with timeout #{timeout}" 
      ok = timeout_execution(timeout, "setup #{ant.params.inspect}", false) do
        @modifier.setup_ant(ant)
      end
      ok &&= timeout_execution( timeout , "check params is #{ant.params.inspect}", false ) do #FIXME: Should we have other value for timeout?
        @modifier.check(ant)
      end
      ok
    end

    # Run method
    # +ant+:: Ant object
    def run(ant)
      timeout = @modifier.get_run_time(ant)
      change_status(:run)
      timeout_execution(timeout, "run #{ant.to_s}") do
        @modifier.run_ant(ant)
      end
    end

    # Return logger object 
    def logger
      Log.logger_for host
    end

    # Setup creep configuration
    # +creep_configuration+:: Ant object
    def configure(creep_configuration)
      @hill_cfg = creep_configuration
      @host = @hill_cfg['host']
      @user = @hill_cfg['user']
      @password = @hill_cfg['password']
      @name = @hill_cfg['name']
      @connection_pool = @config.get_connection_class.new(self)
    end
 
    # Execute command on creep
    # +command+:: Command to run
    # +timeout+:: Timeout for command. If nil - no timeout
    def exec!(command, timeout=nil)
      logger.info("Executing: #{command}")
      stderr,stdout = '', ''
      stdout, stderr = timeout_execution(timeout, "exec!(#{command})") do
        @connection_pool.exec(command)
      end
      logger.info("STDERR: #{stderr}") unless stderr.empty?
      logger.info("STDOUT: #{stdout}") unless stdout.empty?
      logger.info("Executing done")
      stdout
    end

    # Silent version of exec!. Return NoFreeConnection error instance if failed to execute
    def run_once(command, timeout = nil)
      exec!(command,timeout)    
    rescue NoFreeConnectionError => ex
      ex
    end

    # Execute block with timeout
    # +timeout+:: Timeout in seconds or nil if no timeout
    # +process+:: description string, describing process where timeout happened
    # +default_responce+:: default responce if timeout was raised
    def timeout_execution(timeout=nil, process = nil, default_response = ['', ''])
      result = default_response
      begin
        Timeout::timeout( timeout ) do
          result = yield 
        end
      rescue Timeout::Error => e
        change_status(:error)
        logger.error "#{self.host}: timeout error for #{process.to_s}"
      end
      result
    end

    # Create string representation of Creep
    def to_s
      took_time = Time.at(Time.now - @start_time).gmtime.strftime('%R:%S')
      "%s (%i): %s (%s): %s " % [@hill_cfg['host'], @processed, status, took_time,  @current_ant]
    end

    # Retunr if creep is active
    def active?; @active; end

    # Deactivate creep and set status to +:disabled+
    def disable!
      @active = false
      change_status(:disabled)
    end

    # Activate creep and set status to +:wait+
    def enable!
      @active = true
      change_status(:wait)
    end

    # Check if creep is busy
    # "Free" statuses are +:wait+, +:disabled+, +:error+
    def busy?
      !(@status == :wait || @status == :disabled || @status == :error)
    end

    # Start service
    def service
      loop do
        if !active? 
          logger.debug("Node was disabled")
          change_status(:disabled) 
          sleep @config.sleep_interval
        elsif @queen.active? && ant = self.require_ant 
          logger.debug("Setupping and processing ant")
          setup_and_process_ant(ant)
        else
          logger.debug("Waiting for more ants or release")
          change_status(:wait)
          sleep @config.sleep_interval
        end
      end
      @connection_pool.destroy
    end

    # Kill all connections
    def kill_connections
      @connection_pool.destroy
    end

    # Change status and timer for this status of creep
    def change_status(status)
      unless @status == status
        @status = status
        @start_time = Time.now
      end
    end

    # Execute block without raising errors
    def safe
      begin
        yield
      rescue NoFreeConnectionError => e
        disable!
        custom_data['disabled_reason'] = :no_free_connections
        custom_data['disabled_description'] = 'Cannot find free connection or create new one'
        logger.error "#{e}\n#{e.backtrace}" 
      rescue => e
        change_status(:error)
        logger.error "#{e}\n#{e.backtrace}" 
      end
    end
  end
end

