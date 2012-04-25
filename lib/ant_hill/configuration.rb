module AntHill
  class Configuration
    attr_reader :init_time
    
    def initialize
      @init_time = Time.now
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
    end

    def require_libs
      basedir = @configuration['basedir']
      lib_path = @configuration['lib_path']

      require File.join(basedir,lib_path)
    rescue LoadError => e
      STDERR 
    end

    def validate
      strict_attrs = ['basedir', 'lib_path', 'types', 'creeps' ]
      error = false
      unless strict_attrs.all?{|a| @configuration[a]}
        STDERR.puts "Configuration file is invalid! Pls. define #{strict_attre.find{|a| !@configuration[a]}.inspect} keys in it"
        exit(1)
      end
      if @configuration['types'].length == 0
        STDERR.puts "Configuration file is invalid! Pls. define at least one colony type in types section" if @configuration['types'].length == 0
        exit(1)
      end
      if @configuration['creeps'].length == 0
        STDERR.puts "Configuration file is invalid! Pls. define at least one creep type in creeps section"
        exit(1)
      end 
    end

    def ant_colony_class(type=nil)
      type ||= @configuration['default_type']
      get_class_by_type_and_object(type, 'ant_colony_class')
    end

    def creep_modifier_class(type=nil)
      type ||= @configuration['default_type']
      get_class_by_type_and_object(type, 'creep_modifier_class')
    end

    def creeps
      @configuration['creeps']
    end
    
    def sleep_interval
      self[:sleep_interval]
    end

    def get_class_by_type_and_object(type, object)
      if @configuration[type] && klass = @configuration[type][object]
        if defined?(klass)
          return Kernel.const_get(klass)
        else
          Log.logger_for(:configuration).error("No such class defined: #{klass}")
        end
      else
          Log.logger_for(:configuration).error("No class class configuration defined for #{object} and type #{type}")
      end
      return nil
    end

    def [](key)
      @configuration[key.to_s]
    end

    class << self
      def config(filename = ARGV[0])
        return @@config if @@config
        @@config =  self.new(filename)
        @@config.parse_yaml(filename)
        @@config.validate
        @@config.require_libs
        @@config
      end
    end
  end
end
