module AntHill
  class Creep
    attr_reader :host, :user, :password, :status, :connection_pool, :logger, :processed, :passed, :start_time, :hill_cfg, :current_ant
    attr_accessor :active, :current_params, :custom_data
    include DRbUndumped
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
    end
   
    def require_ant
      while Queen.locked?
        sleep rand
      end

      ant = @queen.find_ant(@current_params)
    end

    def from_hash(hash)
      @current_params = hash[:current_parmas] || {}
      @custom_data = hash[:custom_data] || {}
      @status = hash[:status] || :wait
      @processed = hash[:processed] || 0
      @passed = hash[:passed] || 0
      @active = hash[:active] || true
      @start_time = hash[:start_time] || Time.now
      @hill_cfg.merge!(hash[:hill_cfg] || {})
    end

    def to_hash
      {
        :id => object_id,
        :current_params => @current_params,
        :custom_data => @custom_data,
        :status => @status,
        :processed => @processed,
        :passed => @passed,
        :active => @active,
        :start_time => @start_time,
        :hill_cfg => @hill_cfg
      }
    end

    def setup_and_process_ant(ant)
      @current_ant = ant
      @modifier = ant.colony.creep_modifier_class.new(self)
      ant.start
      begin
        before_process(ant)
        ok = setup(ant)
        if ok
          @current_params = ant.params
          run(ant)
        else
          setup_failed(ant)
        end
      rescue => e
        change_status(:error)
        logger.error "#{e}\n#{e.backtrace}" 
      ensure
        ant.finish
        after_process(ant)
        @processed+=1
        @passed +=1 if @current_ant.execution_status.to_sym == :passed
        @current_ant = nil
      end
    end

    def before_process(ant)
      @modifier.before_process(ant)
    rescue => e
      logger.error "There was an error during before_process method: #{e}:\n #{e.backtrace}"
    end

    def after_process(ant)
      @modifier.after_process(ant)
    rescue => e
      logger.error "There was an error during after_process method: #{e}:\n #{e.backtrace}"
    end

    def setup_failed(ant)
      @modifier.setup_failed(ant)
    rescue => e
      logger.error "There was an error during setup_failed method: #{e}:\n #{e.backtrace}"
    end

    def setup(ant)
      timeout = 0
      begin 
        timeout = @modifier.get_setup_time(ant, @current_params)
      rescue => e
        logger.error "There was an error getting setup time: #{e}:\n #{e.backtrace}"
      end
      change_status(:setup)
      ok = false
      begin
        logger.debug "executing setup method with timeout #{timeout}" 
        ok = timeout_execution(timeout, "setup #{ant.params.inspect}") do
          @modifier.setup_ant(ant)
        end
        ok &&= timeout_execution( timeout , "check params is #{ant.params.inspect}") do #FIXME: Should we have other value for timeout?
          @modifier.check(ant)
        end
      rescue => e
        logger.error "There was an error processing setup and check: #{e}:\n #{e.backtrace}"
      end
      ok
    end

    def run(ant)
      timeout = @modifier.get_run_time(ant)
      change_status(:run)
      timeout_execution(timeout, "run #{ant.to_s}") do
        @modifier.run_ant(ant)
      end
    end

    def logger
      Log.logger_for host
    end

    def configure(hill_configuration)
      @hill_cfg = hill_configuration
      @host = @hill_cfg['host']
      @user = @hill_cfg['user']
      @password = @hill_cfg['password']
      @connection_pool = @config.get_connection_class.new(self)
    end
  
    def exec!(command, timeout=nil)
      logger.info("Executing: #{command}")
      stderr,stdout = '', ''
      stdout, stderr = timeout_execution(timeout, "exec!(#{command})") do
        connection_pool.exec(command)
      end
      logger.info("STDERR: #{stderr}") unless stderr.empty?
      logger.info("STDOUT: #{stdout}") unless stdout.empty?
      logger.info("Executing done")
      stdout
    end

    def timeout_execution(timeout=nil, process = nil)
      result = ['','']
      begin
        if timeout
          Timeout::timeout( timeout ) do
            result = yield 
          end
        else
          result = yield 
        end
      rescue Timeout::Error => e
        change_status(:error)
        logger.error "#{self.host}: timeout error for #{process.to_s}"
#      rescue Exception => e
#        logger.error "#{e}\n#{e.backtrace}"
      end
      result
    end

    def to_s
      took_time = Time.at(Time.now - @start_time).gmtime.strftime('%R:%S')
      "%s (%i): %s (%s): %s " % [@hill_cfg['host'], @processed, status, took_time,  @current_ant]
    end

    def active?; @active; end

    def service
      while true

        if !active? 
          logger.debug("Node was disabled")
          change_status(:disabled) 
          sleep @config.sleep_interval
        elsif ant = self.require_ant 
          logger.debug("Setupping and processing ant")
          setup_and_process_ant(ant)
        else
          logger.debug("Waiting for more ants or release")
          change_status(:wait) 
          sleep @config.sleep_interval
        end
      end
      connection_pool.destroy
    end

    def kill_connections
      connection_pool.destroy
    end

    def change_status(status)
      return if @status == status
      @status = status
      @start_time = Time.now
    end
  end
end

