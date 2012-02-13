module AntHill
  class Configuration
    attr_reader :init_time
    def initialize(filename)
      @init_time = Time.now
      parse_yaml(filename)
    end
    def parse_yaml(filename)
      begin
        @configuration = YAML::load_file(filename)
      rescue Exception => ex
        STDERR.puts "Couldn't find config file #{filename}"
        STDERR.puts ex
        STDERR.puts ex.backtrace
        exit(1)
      end
      basedir = @configuration['basedir']
      lib_path = @configuration['lib_path']
      require File.join(basedir,lib_path)
    end

    def match_proc_for_param(param)
      if AntHillExtension::Matchers.method_defined?(param)
        return AntHillExtension::Matchers.method(param)
      else
        return proc{|a,b| a == b}
      end
    end

    def finder(type=nil)
      type ||= @configuration['default_type']
      AntColonyFinder.instance(type)
    end

    def matcher(type=nil)
      type ||= @configuration['default_type']
      Matcher.instance(type)
    end

    def setupper(type=nil)
      type ||= @configuration['default_type']
      CreepSetupper.instance(type)
    end

    def runner(type=nil)
      type ||= @configuration['default_type']
      AntRunner.instance(type)
    end
    
    def change_time_for_param(param)
      @configuration["change_#{param}_time"] || 0
    end

    def sleep_interval
      self[:sleep_interval]
    end

    def [](key)
      @configuration[key.to_s]
    end

    class << self
      def config(filename = ARGV[0])
        @@config ||= self.new(filename)
      end
    end
  end
end
