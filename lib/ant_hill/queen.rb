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
    end

    def size
      @ants.size
    end

    def service(cfg={})
      @threads = []
      spawn_creeps(@config.creeps)
      spawn_drb_queen
      spawn_colonies_processor
      @threads.each{|t| t.join}
    rescue => e
      logger.error "There was an error in queen. Details: #{e}\n#{e.backtrace.join("\n")}"
    end

    def create_colony(params={})
      type = params['type']
      colony_class = @config.ant_colony_class(type)
      if colony_class
        colony = colony_class.new(params)
        @colony_queue << colony
        @colonies << colony
      else
        logger.error "Couldn't process request #{params} because of previous errors"
      end
    end

    def spawn_creeps(creeps)
      @creeps = []
      creeps.each do |creep_config|
        @threads << Thread.new{
          c = Creep.new
          @creeps << c
          c.configure(creep_config)
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
          colony = @colony_queue.pop
          if colony
            new_ants = colony.get_ants
            add_ants(new_ants)
          end
          sleep 1
        end
      }
    end

    def add_ants(ants)
      @ants += ants
    end

    def find_ant(params)
      @lock = true
      @@mutex.synchronize{
        return nil if @ants.empty?
        ants = prioritized_ants(params)
        winner = ants.pop
        winner
      }
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
      creeps.each{|creep|
        creep.active = false
      }
      while creeps.any?{|creep| creep.status != :disabled }
        sleep 1
      end
    end

    def release
      creeps.each{|creep|
        creep.active = true
      }
    end

    def find_colonies(params)
      @colonies.select do |colony| 
        colony.is_it_me?(params)
      end
    end

    def kill_colony(params)
      to_kill = find_colonies(params)
      @@mutex.synchronize{
        to_kill.each do |colony|
          colony.kill
          @ants.reject!{|ant|
            ant.colony == colony
          }
        end
      }
    end

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
