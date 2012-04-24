module AntHill
  class Creep
    attr_reader :host, :user, :password, :status, :ssh_pool, :logger
    def initialize(queen=Queen.queen, config=Configuration.config)
      @config = config
      @queen = queen
      @ssh_pool = []
      @current_configuration = {}
      @status = :wait
      @current_ant = nil
      @processed = 0
      @start_time = Time.now
    end
    
    def require_ant
      while Queen.locked?
        sleep rand
      end
      ant = @queen.find_ant(@current_configuration)
    end

    def setup_and_process_ant(ant)
      setup_params = find_diff(ant)
      @current_ant = ant
      begin 
        setup(setup_params, ant.type)
        run(ant)
      #FIXME
      rescue Exception => e
        change_status(:error)
        logger.error e
      ensure
        @processed+=1
        @current_ant = nil
      end
    end

    def find_diff(ant)
      diff = {}
      config = ant.params
      type = ant.type
      matcher = @config.matcher(type)

      config.each_key{|k|
        diff[k] = config[k] unless matcher.match(k, config[k], @current_configuration[k])
      }
      diff
    end

    def setup(params, type)
      change_status(:setup)
      setupper = @config.setupper(type)
      time = params.inject(0){|time, p| time+=setupper.change_time_for_param(p)}
      #FIXME How calculate time
      begin
        Timeout::timeout( time * 1.5 ) do
          setupper.setup(self,params)
        end
      rescue Timeout::Error => e
        logger.error "#{self.host}: timeout error setupping params #{params.inspect}"
        raise "Setup failed"
      end
      params.each{|param, value|
        @current_configuration[param] = value
      }
    end

    def configure(hill_configuration)
      @hill_cfg = hill_configuration
      @host = @hill_cfg['host']
      @user = @hill_cfg['user']
      @password = @hill_cfg['password']
      start_logger(@hill_cfg['log_path'])
    end

    def start_logger(path="/var/log/ant_hill")
      filename=path+"/#{@host}.log"
      FileUtils.mkdir_p path unless File.exists?(path)
      @logger = Logger.new(path+"/#{@host}.log")
    end

    def exec!(command, timeout=nil)
      logger.info("Executing: #{command}")
      stdout = ""
      stderr = ""
      if timeout
        begin
          Timeout::timeout( timeout ) do
            get_ssh.exec!(command) do |ch, stream, data|
              stderr << data if stream == :stderr
              stdout << data if stream == :stdout
            end
          end
        rescue Timeout::Error => e
          change_status(:error)
          logger.error "#{self.host}: timeout error running command #{command}"
          return nil
        rescue Exception => e
          logger.error e
        end
      else
        get_ssh.exec!(command) do |ch, stream, data|
          stderr << data if stream == :stderr
          stdout << data if stream == :stdout
        end
      end
      logger.info("STDERR: #{stderr}")
      logger.info("STDOUT: #{stdout}")
      stdout
    end

    def to_s
      took_time = Time.at(Time.now - @start_time).gmtime.strftime('%R:%S')
      "%s (%i): %s (%s): %s " % [@hill_cfg['host'], @processed, status, took_time,  @current_ant]
    end

    def service
      while true
        ant = self.require_ant
        if ant
          setup_and_process_ant(ant)
        else
          change_status(:wait) 
          sleep @config.sleep_interval
        end
      end
      kill_ssh
    end

    def get_ssh
      @ssh_pool.delete_if{ |ssh| ssh.closed? }
      ssh = @ssh_pool.find{|ssh| !ssh.busy?}
      return ssh if ssh
      ssh =  Net::SSH.start(host,user, {:password => password, :verbose => (ENV['SSH_DEBUG'] && ENV['SSH_DEBUG'].to_sym) || :fatal })
      ssh.send_global_request("keepalive@openssh.com")
      @ssh_pool << ssh
      ssh
    end

    def kill_ssh
      @ssh_pool.each{ |ssh| ssh.shutdown! unless ssh.closed? }
    end

    def change_status(status)
      return if @status == status
      @status = status
      @start_time = Time.now
    end

    def run(ant)
      change_status(:run)
      runner = @config.runner(ant.type)
      runner.run(ant,self)
    rescue Exception => e
      @status = :error
      logger.error e
    end
  end
end

