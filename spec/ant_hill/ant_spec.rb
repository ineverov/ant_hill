require 'spec_helper'

module AntHill
  describe Ant do
    before :each do
      config = double("config")
      config.stub(:creep_modifier_class){|type| "Creep modifier for #{type}" }
      config.stub(:log_level){ :log_level }
      config.stub(:log_dir){ log_dir }
      config.stub(:init_time){ Time.at(0)}
      Configuration.stub(:config){config}
      
      logger = double("logger")
      Log.stub(:logger_for){logger}        
    end

    let(:ant_colony){ 
      ac = double("ant_colony")
      ac.stub(:type){ "type" }
      ac.stub(:params){ {"type" => "type", "a" => 1, "b" => 2} }
      cmc = double(:creep_modifier_class)
      cm = double(:creep_modifier)
      cmc.stub(:change_time_for_param){|param|
        case param
          when 'a': 1
          when 'b': 2
          else
            0
        end

      }
      cmc.stub(:new){ cm}
      ac.stub(:creep_modifier_class){cmc}
      ac.stub(:change_time_for_param){|param|
        case param
          when 'a': 1
          when 'b': 2
          else
            0
        end

      }
      ac
    }

    let(:ant){Ant.new( { "param1" => "params", "param2" => "param2"}, ant_colony )}

    context "#initialize" do
      it "should have colony" do
        ant.colony.should eql(ant_colony)
      end
      it "should merge colony and self params" do
        ant.params.should eql({ "type" => "type", "a" => 1, "b" => 2, "param1" => "params", "param2" => "param2" })
      end
      it "should have status not_started" do
        ant.status.should eql(:not_started)
      end
    end

    context "#to_s" do
      it "should return string of params" do
        ant.to_s.should eql(ant.params.inspect.to_s)
      end
    end

    context "#change_status" do
      it "should set status" do
        ant.change_status(:started)
        ant.status.should eql(:started)
      end
    end

    context "#priority" do
      it "should have higher priority for matches params" do
        ant.priority({}).should < ant.priority({"a" => 1})
        ant.priority({"a" => 1}).should < ant.priority({"a" => 1, "b" => 2})
      end

      it "should increase priority on sum values defined for param in change_time_for_param method" do
        ant.priority({ "a" => 1 }).should be_within(0.0001).of( ant.priority({"a" => 0}) + 1 )
        ant.priority({ "b" => 2 }).should be_within(0.0001).of( ant.priority({"b" => 0}) + 2 )

      end
      it "should return same value for same params " do
        ant.priority({ "b" => 2 }).should be_within(0.0001).of( ant.priority({"b" => 2}) )
      end

    end

    context "#finished?" do
      it "should return false if ant status is finished" do
        ant.stub(:status){:in_progress}
        ant.finished?.should be_false
      end
      it "should return true if ant status is finished" do
        ant.stub(:status){:finished}
        ant.finished?.should be_true
      end
    end
  end
end
