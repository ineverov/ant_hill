require 'spec_helper'
module AntHill
  describe Configuration do

    before(:each) do
      YAML.stub(:load_file) do |filename| 
        {
          'base_dir' => "a",
          'lib_path' => 'b',
          'sleep_interval' => 1,
          'types' => {
            'a' => {
              'ant_colony_class' => 'first_ant_colony',
              'creep_modifier_class' => 'first_creep_modifier'
            },
            'b' => {
              'ant_colony_class' => 'second_ant_colony',
              'creep_modifier_class' => 'second_creep_modifier'
            }
          },
          'default_type' => 'a',
          'log_path' => 'log_path',
          'creeps' => [
            { 'name' => 1, 'host' => 'host', 'login' => 'login', 'password' => 'password'},
            { 'name' => 2, 'host' => 'host2', 'login' => 'login2', 'password' => 'password2'}
          ] 

        }
      end

      Time.stub(:now) { Time.at(0) }
      File.stub(:join) { 'rubygems'}
    end

    let(:config) { Configuration.new }

    context "#initialize" do
      it "should set init_time" do
        config.init_time == Time.at(0)
      end
    end

    context "#parse_yaml" do
      it "should fail if file not exists" do
        STDERR.should_receive(:puts).with(/Couldn't find config file/)
        YAML.stub(:load_file){raise}
        lambda{ config.parse_yaml("config.yml") }.should raise_error
      end

      it "should load configuration" do
        config.parse_yaml("config.yml")
      end
    end

  end
end
