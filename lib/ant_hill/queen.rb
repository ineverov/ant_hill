require 'drb'

module AntHill
  class Queen
    attr_reader :creeps

    DRB_HOST = '0.0.0.0'
    DRB_PORT = 6666

    def initialize(config = Configuration.config)
      @config = config
      @ants = []
      @colony_queue = []
      trap("INT") do
        puts "Terminating... Pls wait"
        @creeps.each{|c|  c.kill_ssh  }
        @threads.each{|th| th.exit  }
      end
    end

    def size
      @ants.size
    end

    def service(cfg={})
      create_colony(cfg)
      spawn_creeps(@config[:creeps])
    end

    def create_colony(params={})
      type = params['type']
      @colony_queue << AntColony.new(params, type)
    end

    def spawn_creeps(creeps)
      @threads = []
      @creeps = []
      for creep in creeps
        @threads << Thread.new{
          c = Creep.new
          @creeps << c
          c.configure(creep)
          Thread.current["name"]=c.to_s
          c.service
        }
      end
      @threads << Thread.new{
        Thread.current["name"]="main"
        DRb.start_service "druby://#{DRB_HOST}:#{DRB_PORT}", self
      }
      @threads << Thread.new{
        Thread.current["name"]="colony queue processor"
        while true do
          colony = @colony_queue.pop
          if colony
            new_ants = colony.get_ants
            @ants += new_ants
          end
          sleep 1
        end
      }
      @threads.each{|t| t.join}
    end

    def find_ant(params)
      @lock = true
      ants = prioritized_ants(params)
      winner = ants.pop
      @lock = false
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

    class << self
      def locked?
        @@queen.locked?
      end

      def queen
        @@queen ||= self.new
      end

      def drb_queen(host)
        DRb.start_service
        queen = DRbObject.new nil, "druby://#{host}:6666"
      rescue Exception => e
        puts e
      end

      def create_colony(args, host)
        drb_queen(host).create_colony parse_args(args)
      end

      def creeps(host = 'localhost')
        drb_queen(host).creeps
      end

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
