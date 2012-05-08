require 'spec_helper'
module AntHill
  describe Configuration do

    let(:hash){
        {
          'basedir' => "a",
          'lib_path' => 'b',
          'sleep_interval' => 1,
          'log_dir' => 'some_dir',
          'log_level' => ':error',
          'types' => {
            'a' => {
              'ant_colony_class' => 'String',
              'creep_modifier_class' => 'Object'
            },
            'b' => {
              'ant_colony_class' => 'Hash',
              'creep_modifier_class' => 'String'
            },
            'c' => {
              'ant_colony_class' => 'SomeClass',
              'creep_modifier_class' => 'SomeOtherClass'
            }
          },
          'default_type' => 'a',
          'log_path' => 'log_path',
          'creeps' => [
            { 'name' => 1, 'host' => 'host', 'login' => 'login', 'password' => 'password'},
            { 'name' => 2, 'host' => 'host2', 'login' => 'login2', 'password' => 'password2'}
          ] 

        }
    }
    before(:each) do
      YAML.stub(:load_file) {|filename| hash }
      Time.stub(:now) { Time.at(0) }
      File.stub(:join) { 'rubygems'}
      logger = double("logger")
      Log.stub(:logger_for){logger}        
    end

    let(:config) { Configuration.new }
    
    let(:config_parsed){
      c = Configuration.new
      c.parse_yaml("config.yml")
      c
    }

    context "#initialize" do
      it "should set init_time" do
        config.init_time == Time.at(0)
      end
    end

    context "#parse_yaml" do
      it "should fail if file not exists" do
        STDERR.stub(:puts)
        STDERR.should_receive(:puts).with(/Couldn't find config file/)
        YAML.stub(:load_file){raise}
        lambda{ config.parse_yaml("config.yml") }.should raise_error(SystemExit)
      end

      it "should load configuration" do
        config.parse_yaml("config.yml")
        config.instance_variable_get("@configuration").should_not eql({})
      end
    end

    context "#require_libs" do
      it "should require file base_dir+libpath" do
        config_parsed.stub(:require){nil}
        config_parsed.should_receive(:require).with("rubygems")
        config_parsed.require_libs
      end
      it "should require file base_dir+libpath" do
        config_parsed.stub(:require){ raise LoadError }
        config_parsed.should_receive(:require).with("rubygems")
        STDERR.should_receive(:puts).with(/Configuration file is invalid! No such file exists rubygems/)
        config_parsed.require_libs
      end
    end

    context "#validate" do

      context "with valid config" do
        it "should not exit if config is valid" do
          lambda{config_parsed.validate}.should_not raise_error(SystemExit)
        end
      end
      context "with invalid config" do
        before(:each) do
          STDERR.stub(:puts)
        end
        %w{ basedir lib_path types creeps log_dir log_level }.each do |key|
          it "should log error and exit if #{key} unset" do
            new_hash = hash.clone
            new_hash.delete(key)
            YAML.stub(:load_file){|filename| new_hash }
            c = Configuration.new
            c.parse_yaml("config.yml")
            STDERR.should_receive(:puts).with(/Configuration file is invalid! Pls. define .* keys in it/)
            lambda{c.validate}.should raise_error(SystemExit)
          end
        end

        %w{ types creeps }.each do |key|
          it "should log error and exit #{key} has no children" do
            new_hash = hash.clone
            new_hash[key] = []
            YAML.stub(:load_file){|filename| new_hash }
            c = Configuration.new
            c.parse_yaml("config.yml")
            STDERR.should_receive(:puts).with(/Configuration file is invalid! Pls. define at least one .* in #{key} section/)
            lambda{c.validate}.should raise_error(SystemExit)
          end
        end
      end
    end

    context "#creep_modifier_class" do
      it "should return creep_modifier_class from config if type specified" do
        config_parsed.creep_modifier_class('b').should eql(String)
      end
      it "should return creep_modifier_class from config for default type if not type specified" do
        config_parsed.creep_modifier_class.should eql(Object)
      end
    end
    
    context "#ant_colony_class" do
      it "should return creep_modifier_class from config if type specified" do
        config_parsed.ant_colony_class('b').should eql(Hash)
      end
      it "should return creep_modifier_class from config for default type if not type specified" do
        config_parsed.ant_colony_class.should eql(String)
      end
    end

    context "#get_class_by_type_and_object" do
      it "should log error if no class name defiend for given type and object" do
        Log.logger_for.should_receive(:error).with(/No class configuration defined for object and type a/)
        Log.logger_for.should_receive(:error).with(/No class configuration defined for String and type d/)
        config_parsed.get_class_by_type_and_object('a', 'object')
        config_parsed.get_class_by_type_and_object('d', 'String')
      end
      it "should log error if no specified class defiend" do
        Log.logger_for.should_receive(:error).with("No such class defined: SomeClass")
        config_parsed.get_class_by_type_and_object('c', 'ant_colony_class')
      end
    end

    context "#[]" do
      it "should access to configuration with [] method" do
        config_parsed['default_type'].should eql('a')
        config_parsed['default_type'].should eql('a')
      end
    end
    
    context "#method_missing" do
      it "should return default_type from config" do
        config_parsed.default_type.should eql("a")
      end
    end

    context "Configuration#config" do
      let(:config_double){
        config_double = double("config")
        config_double.stub(:parse_yaml){|file| }
        config_double.stub(:validate)
        config_double.stub(:require_libs)
        config_double
      }
      before :each do
        Configuration.method(:remove_class_variable).call(:@@config) if Configuration.class_variable_defined?(:@@config)
      end
      it "should return same object every time" do
        Configuration.stub(:new){config_double}
        config_double.should_receive(:parse_yaml)
        config_double.should_receive(:validate)
        config_double.should_receive(:require_libs)
        Configuration.config.should be_equal(Configuration.config)
      end
      it "should use passed filename for parsing" do
        Configuration.stub(:new){ config_double }
        config_double.should_receive(:parse_yaml).with("filename.yml")
        config_double.should_receive(:require_libs)
        config_double.should_receive(:validate)
        Configuration.config("filename.yml")
      end
      it "should use ARGV[0] as filename for parsing" do
        Configuration.stub(:new){ config_double }
        ARGV[0]='filename.yml'
        config_double.should_receive(:parse_yaml).with("filename.yml")
        config_double.should_receive(:require_libs)
        config_double.should_receive(:validate)
        Configuration.config
      end
    end
  end
end
