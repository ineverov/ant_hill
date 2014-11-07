module AntHill
  # Main class that rule all the kingdom
  class Queen
    # +creeps+:: list of creeps
    # +ants+:: list of ants
    # +colonies+:: list of colonies
    attr_reader :creeps, :ants, :colonies

    # Default host for DRb
    DRB_HOST = '127.0.0.1'
    # Default port for DRb
    DRB_PORT = 6666
    
    include DRbUndumped

    # Initialize
    # +config+:: Configuration object
    def initialize(config = Configuration.config)
      @config = config
      @colonies = []
      @drb_host = config.drb_host
      @drb_port = config.drb_port
      trap("INT") do
        puts "Terminating... Pls wait"
        @creeps.each{|c|  c.kill_connections  }
        @threads.each{|th| th.exit  }
      end
      @active = true
      @colony_queue = AntColonyQueue.new
      @process_colony_queue = SynchronizedObject.new([], [:<<, :select, :shift, :each])
      @loaded_params = {}
    end

    # Return ants size
    def size
      @colony_queue.size
    end

    # Service method
    def service
      @threads = []
      spawn_creeps(@config.creeps)
      spawn_drb_queen
      spawn_colonies_processor
      at_exit do
        save_queen(@config.queen_filename || "queen.yml")
      end
      @threads.each{|t| t.join}
    rescue => e
      logger.error "There was an error in queen. Details: #{e}\n#{e.backtrace.join("\n")}"
    end

    # Create colony
    # +params+:: params for colony
    # +loaded_params+:: loaded params for respawning queen
    def create_colony(params={}, loaded_params = nil)
      colony = @colony_queue.create_colony( params, loaded_params )
      @process_colony_queue << colony
      colony
    end

    # Initialize and start threads for each creep
    # +creeps+: array of hashes with creep params
    #   Example: [{'name' => 'creep1', 'host'=> 'hostname', 'user' => 'login_user', 'password' => 'user_password'}]
    def spawn_creeps(creeps)
      @creeps = []
      loaded_params = @loaded_params[:creeps]
      creeps.each do |creep_config|
        creep_loaded = loaded_params && loaded_params.find{|cr| cr[:hill_cfg]['name'] == creep_config['name'] } || {}
        add_creep(creep_config, creep_loaded)
      end
    end

    # Adding new creep and creatinf thread for it
    # +creep_config+:: hash of params for creep
    #   Example: {'name' => 'creep1', 'host'=> 'hostname', 'user' => 'login_user', 'password' => 'user_password'}
    # +creep_loaded+:: creep loaded from saved file 
    def add_creep(creep_config, creep_loaded={})
      @threads << Thread.new{
        c = Creep.new
        c.configure(creep_config)
        c.from_hash(creep_loaded)
        @creeps << c
        Thread.current["name"]=c.to_s
        c.service
      }
    end

    # Delete creep
    # +creep_name+:: creep name to delete
    # +graceful+:: default true, if true finish processing before delete
    def delete_creep(creep_name, graceful=true)
      creep = @creeps.find{|c| c.name.to_s =~ /#{creep_name}/}
      thread = @threads.find{|t| t['name'] == creep.to_s} if creep
      if graceful
        creep.disable!
        while creep.busy? do
          sleep 1
        end
      end
      thread.terminate if thread
      @threads.delete(thread) if thread
      @creeps.delete(creep) if creep
    end

    # Create drb interface for queen
    def spawn_drb_queen
      @threads << Thread.new{
        begin 
          Thread.current["name"]="main"
          DRb.start_service "druby://#{@drb_host || DRB_HOST}:#{@drb_port || DRB_PORT}", self
          DRb.thread.join
        rescue => e
          logger.error "There was an error in drb_queen =(. Details: #{e}\n#{e.backtrace}"
        end
      }
    end

    # Create thread for processing new colonies
    def spawn_colonies_processor
      @threads << Thread.new{
        Thread.current["name"]="colony queue processor"
        while true do
          if @active
            @colony_processor_busy = true
            colony = @process_colony_queue.shift
            if colony && !colony.killed?
              colony.get_ants
              @colony_queue.add_colony(colony) unless colony.killed?
            end
            @colony_processor_busy = false
          end
          sleep 1
        end
      }
    end

    # Reset priority for specified creep for all ants
    def reset_priority_for_creep(creep)
      @colony_queue.reset_priority_for_creep(creep)
    end
 
    # Return logger for queen
    def logger
      Log.logger_for(:queen)
    end

    # Suspend all processing and wait while it's done 
    def suspend
      @active = false
      while creeps.any?{|creep| creep.busy? }
        sleep 1
      end
      while @colony_processor_busy
        sleep 1
      end
    end

    # Release all processing
    def release
      @active = true
    end

    # Find colonies for params
    # +params+:: hash of params to match colony
    def find_colonies(params)
      @process_colony_queue.select do |colony| 
        colony.is_it_me?(params)
      end
    end
    private :find_colonies

    def find_ant(creep)
      @colony_queue.find_ant(creep)
    end

    def kill_colony(params)
      if params.is_a?(AntColony)
        to_kill = [ params ]
      else
        to_kill = find_colonies(params)
      end
      to_kill.each do |colony|
        colony.kill
        @colony_queue.delete_colony(colony)
      end
    end

    # Save queen to file
    # +filename+:: filename to store queen data
    def save_queen(filename)
      queen_hash = to_hash
      File.open(filename, "w+") { |f| f.puts queen_hash.to_yaml}
    end

    # Restore queen from file
    # +filename+:: filenme with queen data
    def restore_queen(filename)
      hash = YAML::load_file(filename)
      @loaded_params = hash
      from_hash(hash)
    end

    # Initialize queen from loaded hash
    # +hash+:: queen hash
    def from_hash(hash)
      @config.from_hash(hash[:configuration])
      @colony_queue.from_hash(hash[:colony_queue])
      hash[:process_colony_queue].each do |colony_data|
        colony = @colony_queue.create_colony
        @process_colony_queue << colony
      end
    end

    # Convert queen to hash
    # +include_finished+:: should finished colonies and ants be includes to hash?
    def to_hash(include_finished = false)
      {
        :process_colony_queue => @process_colony_queue.collect{|pc| pc.to_hash},
        :colony_queue => @colony_queue.to_hash,
        :creeps => @creeps.collect{|c| c.to_hash },
        :configuration => @config.to_hash 
      }
    end

    def daemonize
      Process.daemon
    end

    # Check if queen is active
    def active?; @active; end

    # Singleton object
    class << self
      # Check if mutex is locked
      def locked?
        @@mutex.locked?
      end

      # Return or create current queen
      def queen
        @@queen ||= self.new
      end

      # Connect to DRb interface of queen
      # +host+:: host where DRb is started
      def drb_queen(host = 'localhost')
        DRb.start_service
        queen = DRbObject.new_with_uri "druby://#{host}:6666"
      rescue => e
        puts e
      end

      # Creates colony for arguments
      # +args+:: command line arguments
      # +host+:: DRb queen host
      def create_colony(args, host = 'localhost')
        drb_queen(host).create_colony parse_args(args)
      end

      # Return list of creeps
      # +host+:: DRb queen host
      def creeps(host = 'localhost')
        drb_queen(host).creeps
      end

      # Kill colony(colonies) matching arguments
      # +args+:: command line arguments
      # +host+:: DRb queen host
      def kill_colony(args, host = 'localhost')
        drb_queen(host).kill_colony parse_args(args)
      end

      private
      # Convert command line arguments to hash
      # +args+:: command line arguments
      def parse_args(args)
        result = {}
        args.each do |arg|
          pair = arg.split("=")
          result[pair[0]]=pair[1]
        end
        result
      end
    end
  end
end
