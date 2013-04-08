module AntHill
  class Queen
    attr_reader :creeps, :ants, :colonies

    DRB_HOST = '127.0.0.1'
    DRB_PORT = 6666
    
    include DRbUndumped

    def initialize(config = Configuration.config)
      @config = config
      @ants = []
      @colony_queue = []
      @colonies = []
      @drb_host = config.drb_host
      @drb_port = config.drb_port
      @@mutex = Mutex.new
      trap("INT") do
        puts "Terminating... Pls wait"
        @creeps.each{|c|  c.kill_connections  }
        @threads.each{|th| th.exit  }
      end
      @active = true
      @loaded_params = {}
    end

    def size
      @ants.size
    end

    def service
      @threads = []
      spawn_creeps(@config.creeps)
      spawn_drb_queen
      spawn_colonies_processor
      @threads.each{|t| t.join}
    rescue => e
      logger.error "There was an error in queen. Details: #{e}\n#{e.backtrace.join("\n")}"
    end

    def create_colony(params={}, loaded_params = nil)
      type = params['type']
      type = loaded_params[:params]['type'] if loaded_params
      colony_class = @config.ant_colony_class(type)
      if colony_class
        colony = colony_class.new(params)
        colony.from_hash(loaded_params) if loaded_params
        @colony_queue << colony unless loaded_params
        @colonies << colony
      else
        logger.error "Couldn't process request #{params} because of previous errors"
      end
      colony
    end

    def spawn_creeps(creeps)
      @creeps = []
      loaded_params = @loaded_params[:creeps]
      creeps.each do |creep_config|
        creep_loaded = loaded_params && loaded_params.find{|cr| cr[:hill_cfg]['name'] == creep_config['name'] } || {}
        @threads << Thread.new{
          c = Creep.new
          @creeps << c
          c.configure(creep_config)
          c.from_hash(creep_loaded)
          Thread.current["name"]=c.to_s
          c.service
        }
      end
    end

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

    def spawn_colonies_processor
      @threads << Thread.new{
        Thread.current["name"]="colony queue processor"
        while true do
          if @active
            @colony_processor_busy = true
            colony = @colony_queue.pop
            if colony
              new_ants = colony.get_ants
              add_ants(new_ants)
            end
            @colony_processor_busy = false
          end
          sleep 1
        end
      }
    end

    def add_ants(ants)
      @ants += ants
    end

    def find_ant(params)
      return nil if @ants.empty?
      winner = nil
      @@mutex.synchronize{
        ants = prioritized_ants(params)
        winner = ants.pop
      }
      winner
    end

    def prioritized_ants(params)
      @ants.sort! do |a,b|
        a.priority(params) <=> b.priority(params)
      end
    end

    def locked?
      @lock
    end


    def logger
      Log.logger_for(:queen)
    end

    def suspend
      @active = false
      creeps.each{|creep|
        creep.active = false
      }
      while creeps.any?{|creep| creep.status != :disabled }
        sleep 1
      end
      while @colony_processor_busy
        sleep 1
      end
    end

    def release
      creeps.each{|creep|
        creep.active = true
      }
      @active = true
    end

    def find_colonies(params)
      @colonies.select do |colony| 
        colony.is_it_me?(params)
      end
    end

    def kill_colony(params)
      if params.is_a?(AntColony)
        to_kill = [ params ]
      else
        to_kill = find_colonies(params)
      end
      @@mutex.synchronize{
        to_kill.each do |colony|
          colony.kill
          @ants.reject!{|ant|
            ant.colony == colony
          }
          @colonies.delete(colony)
        end
      }
    end

    def save_queen(filename)
      queen_hash = to_hash
      File.open(filename, "w+") { |f| f.puts queen_hash.to_yaml}
    end

    def restore_queen(filename)
      hash = YAML::load_file(filename)
      @loaded_params = hash
      from_hash(hash)
    end

    def from_hash(hash)
      colonies = hash[:colonies]
      tmp = {}
      @config.from_hash(hash[:configuration])
      colonies.each do |col|
        colony = create_colony({},col)
        tmp[col[:id]] = colony
      end
      @colonies.each{|c| add_ants(c.ants)}
      @colony_queue = colonies.collect{|cq| tmp[cq]}
    end

    def to_hash(include_finished = false)
      {
        :colonies => @colonies.collect{|ac| ac.to_hash(include_finished) },
        :colony_queue => @colony_queue.collect{|ac| ac.object_id },
        :creeps => @creeps.collect{|c| c.to_hash },
        :configuration => @config.to_hash 
      }
    end

    def active?; @active; end

    class << self
      def locked?
        @@mutex.locked?
      end

      def queen
        @@queen ||= self.new
      end

      def drb_queen(host = 'localhost')
        DRb.start_service
        queen = DRbObject.new_with_uri "druby://#{host}:6666"
      rescue => e
        puts e
      end

      def create_colony(args, host = 'localhost')
        drb_queen(host).create_colony parse_args(args)
      end

      def creeps(host = 'localhost')
        drb_queen(host).creeps
      end

      def kill_colony(args, host = 'localhost')
        drb_queen(host).kill_colony parse_args(args)
      end

      private
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
