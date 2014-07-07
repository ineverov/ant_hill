module AntHill
  # Configuration of AntHill
  class Configuration
    # Attribute readers
    # +init_time+:: initialize time
    attr_reader :init_time
    include DRbUndumped
    # Default output string lengths for console monitor
    DEFAULT_MONITOR = { 'hostname_lenght' => 15, 'processed_lenght' => 7} 

    # Initialize
    def initialize
      @init_time = Time.now
      @config_file = ''
      @configuration = {}
    end
   
    # Convert config to hash
    def to_hash
      {:init_time => @init_time}
    end

    # Convert hash to config
    def from_hash(hash)
      if hash
        @init_time = hash[:init_time]
      end
    end 

    # Parse configuration file
    # +filename+:: configuration file path
    def parse_yaml(filename)
      @config_file = filename
      begin
        @configuration = YAML::load_file(filename)
      rescue => ex
        STDERR.puts "Couldn't find config file #{filename}"
        STDERR.puts ex
        STDERR.puts ex.backtrace
        exit(1)
      end
    end

    # Require ant_hill implementations
    def require_libs
      basedir = @configuration['basedir']
      lib_path = @configuration['lib_path']
      $LOAD_PATH << basedir
      require File.join(basedir,lib_path)
    rescue LoadError => e
      STDERR.puts "Configuration file is invalid! No such file exists #{File.join(basedir, lib_path)}\n#{e}\n#{e.backtrace}" 
    end

    # Validate minimum configuration is set
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

    # return class for colony type
    # +type+:: AntColony type, if nil defult_type key will be used
    def ant_colony_class(type=nil)
      get_class_by_type_and_object(type || default_type, 'ant_colony_class')
    end

    # Return +CreepModifier+ class for colony type
    # +type+:: AntColony type, if nil defult_type key will be used
    def creep_modifier_class(type=nil)
      get_class_by_type_and_object(type || default_type, 'creep_modifier_class')
    end

    # Get class for given parameters
    # +type+:: colony type
    # +object+:: ant_colony_class or creep_modifier_class
    def get_class_by_type_and_object(type, object)
      if @configuration['types'][type] && klass = @configuration['types'][type][object]
        return get_const_by_name(klass)
      else
        Log.logger_for(:configuration).error("No class configuration defined for #{object} and type #{type}")
      end
      return nil
    end

    # Get constant by name
    # +name+:: constant name
    def get_const_by_name(name)
      consts = name.split("::")
      obj = Object
      begin
        consts.each{|const| 
          obj = obj.const_get(const)
        }
      rescue
        Log.logger_for(:configuration).error("No such class defined: #{name}")
      end
      return obj
    end

    # Class used for accesing creep node
    def get_connection_class
      get_const_by_name(connection_class)
    end

    # monitor configuration
    def monitor
      return @monitor if @monitor
      @monitor = DEFAULT_MONITOR
      config = @configuration['monitor'] || {}
      @monitor = @monitor.merge(config)
    end

    # get configuration value by name
    def [](key)
      @configuration[key.to_s]
    end

    # allow to use config.<key> syntax
    # +key+:: return value for specified key
    def method_missing(key, *args)
      meth = key.to_s.gsub(/^get_/, "")
      if @configuration.has_key?(meth)
        @configuration[meth]
      else
        STDERR.puts "No key #{meth} defined in #{@config_file}"
      end
    end

    # Singleton object
    class << self
      # Return configuration object
      # [+filename+]:: config filename or first argument
      def config(filename = ARGV[0])
        return @@config if defined?(@@config)
        @@config =  self.new
        @@config.parse_yaml(filename)
        @@config.validate
        @@config.require_libs
        @@config
      end
    end
  end
end
