module AntHill
  class Configuration
    attr_reader :init_time
    
    def initialize
      @init_time = Time.now
      @config_file = ''
      @configuration = {}
    end
    
    def parse_yaml(filename)
      @config_file = filename
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
      STDERR.puts "Configuration file is invalid! No such file exists #{File.join(basedir, lib_path)}" 
    end

    def validate
      strict_attrs = ['basedir', 'lib_path', 'types', 'creeps', 'log_dir', 'log_level']
      error = false
      unless strict_attrs.all?{|a| @configuration[a]}
        STDERR.puts "Configuration file is invalid! Pls. define #{strict_attrs.find{|a| !@configuration[a]}.inspect} keys in it"
        exit(1)
      end
      if @configuration['types'].length == 0
        STDERR.puts "Configuration file is invalid! Pls. define at least one colony type in types section"
        exit(1)
      end
      if @configuration['creeps'].length == 0
        STDERR.puts "Configuration file is invalid! Pls. define at least one creep type in creeps section"
        exit(1)
      end 
    end

    def ant_colony_class(type=nil)
      get_class_by_type_and_object(type || default_type, 'ant_colony_class')
    end

    def creep_modifier_class(type=nil)
      get_class_by_type_and_object(type || default_type, 'creep_modifier_class')
    end

    def get_class_by_type_and_object(type, object)
      if @configuration['types'][type] && klass = @configuration['types'][type][object]
        if !klass.nil? && Object.const_defined?(klass)
          return Kernel.const_get(klass)
        else
          Log.logger_for(:configuration).error("No such class defined: #{klass}")
        end
      else
        Log.logger_for(:configuration).error("No class configuration defined for #{object} and type #{type}")
      end
      return nil
    end

    def [](key)
      @configuration[key.to_s]
    end

    def method_missing(method, *args)
      if @configuration[method.to_s]
        @configuration[method.to_s]
      else
        STDERR.puts "No key #{method} defined in #{@config_file}"
      end
    end

    class << self
      def config(filename = ARGV[0])
        return @@config if defined?(@@config)
        @@config =  self.new(filename)
        @@config.parse_yaml(filename)
        @@config.validate
        @@config.require_libs
        @@config
      end
    end
  end
end
