module AntHill
  class Creep
    attr_reader :host, :user, :password, :status, :connection_pool, :logger, :processed, :passed, :start_time, :hill_cfg, :current_ant
    attr_accessor :active, :custom_data
    include DRbUndumped
    module Trackable
      def self.extended(obj)
        class << obj 
          attr_reader :changed_params
          alias :"old []=" :[]=  
          def reset_changed
            @changed_params = []
          end

          def []=(key, new_value)
            old_value = self[key] if has_key?(key)
            method(:"old []=").call(key,new_value)
            if old_value != new_value
              @changed_params ||= []
              @changed_params << key unless @changed_params.index(key)
            end
          end
        end
      end
    end

    def initialize(queen=Queen.queen, config=Configuration.config)
      @config = config
      @queen = queen
      @current_params = {}
      @current_params.extend(Trackable)
      @custom_data = {}
      @status = :wait
      @current_ant = nil
      @processed = 0
      @passed = 0
      @active = true
      @start_time = Time.now
      @modifiers = {}
      @changed_params = []
    end
    
    def current_params
      @current_params
    end

    def changed_params
      current_params.changed_params
    end

    def current_params=(new_params)
      new_params.each do |k,v|
        @current_params[k]=v
      end
    end
   
    def require_ant
      while Queen.locked?
        sleep rand
      end

      time = Time.now
      ant = @queen.find_ant(self)
      logger.debug "Find min ant took #{Time.now - time}"
      ant
    end

    def priority(ant)
      mod = modifier(ant)
      ant.prior - mod.get_setup_time(ant)
    end

    def from_hash(hash)
      @current_params = (hash[:current_parmas] || {}).tap{|cp| cp.extend(Trackable)}
      @custom_data = hash[:custom_data] || {}
      @status = hash[:status] || :wait
      @processed = hash[:processed] || 0
      @passed = hash[:passed] || 0
      @active = hash[:active].nil? ? true : hash[:active]
      @start_time = hash[:start_time] || Time.now
      @hill_cfg.merge!(hash[:hill_cfg] || {})
    end

    def modifier(ant)
      @modifiers[ant.type] ||= ant.colony.creep_modifier_class.new(self)
    end

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

    def setup_and_process_ant(ant)
      @current_ant = ant
      @modifier = modifier(ant)
      ant.start
      current_params.reset_changed
      safe do
        before_process(ant)
        ok = setup(ant)
        if ok
          ant.params.each do |k,v|
            if !@modifier.creep_params || @modifier.creep_params.include?(k)
              self.current_params[k]=v
            end
          end
          run(ant)
        else
          setup_failed(ant)
        end
      end
      ant.finish
      safe{ after_process(ant) }
      Queen.queen.reset_priority_for_creep(self)
      @processed+=1
      @passed +=1 if @current_ant.execution_status.to_sym == :passed
      @current_ant = nil
    end

    def before_process(ant)
      @modifier.before_process(ant)
    end

    def after_process(ant)
      @modifier.after_process(ant)
    end

    def setup_failed(ant)
      @modifier.setup_failed(ant)
    end

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

    def run_once(command, timeout = nil)
      exec!(command,timeout)    
    rescue NoFreeConnectionError => ex
      ex
    end

    def timeout_execution(timeout=nil, process = nil, default_response = ['', ''])
      result = default_response
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
      end
      result
    end

    def to_s
      took_time = Time.at(Time.now - @start_time).gmtime.strftime('%R:%S')
      "%s (%i): %s (%s): %s " % [@hill_cfg['host'], @processed, status, took_time,  @current_ant]
    end

    def active?; @active; end

    def disable!(&block)
      @active = false
      change_status(:disabled, &block)
    end

    def busy?
      !(@status == :wait || @status == :disabled || @status == :error)
    end

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
      connection_pool.destroy
    end

    def kill_connections
      connection_pool.destroy
    end

    def change_status(status)
      @status = status
      @start_time = Time.now
      yield(self) if block_given?
    end

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

