require 'spec_helper'

module AntHill
  describe AntColony do
    let(:params){ {"type" => "type", "a" => 1, "b" => 2 } }
    let(:colony){ AntColony.new(params) }
    
    before :each do
      config = double("config")
      config.stub(:creep_modifier_class){|type| "Creep modifier for #{type}" }
      config.stub(:log_level){ :log_level }
      config.stub(:log_dir){ log_dir }
      config.stub(:init_time){ Time.now}
      Configuration.stub(:config){config}
      
      logger = double("logger")
      Log.stub(:logger_for){logger}        
    end

    context "#initialize" do
      it "should store params" do
        colony.params.should eql(params)
      end
    end

    context "#type" do
      it "should return type from params" do
        colony.type.should eql("type")
      end
    end

    context "#creep_modifier_class" do
      it "should return creep modifier class for type" do
        Configuration.config.should_receive(:creep_modifier_class).with("type").and_return("Creep modifier for type")
        colony.creep_modifier_class.should eql("Creep modifier for type")
      end

      it "should log error if no such type defined" do
        test_params = params
        test_params['type']="wrong_type"

        colony = AntColony.new(params)
        Configuration.config.should_receive(:creep_modifier_class).with("wrong_type").and_return(nil)
        Log.logger_for.should_receive(:error).with("Colony will die without creep modifier ;(")
        colony.creep_modifier_class.should be_nil
      end
    end

    context "#spoiled?" do
      it "should be spoiled if no creep modifier class was set" do
        test_params = params
        test_params['type']="wrong_type"
        colony = AntColony.new(params)
        colony.spoiled?.should be_true
      end
    end

    context "#get_ants" do
      it "should add self params to all ants " do
        colony.stub(:search_ants){ [{:param1 => 1, :param2 => 2},{ :param1 => 3, :param2 => 2}] }
        ants = colony.get_ants
        ants.should_not be_empty
        ants.each{|ant|
          ant.params['type'].should eql('type')
          ant.params['a'].should eql(1)
          ant.params['b'].should eql(2)
          ant.params[:param2].should eql(2)
        }
        ants[0].params[:param1].should eql(1)
        ants[1].params[:param1].should eql(3)
      end

      it "should call after_search" do
        colony.stub(:search_ants){ [{:param1 => 1, :param2 => 2},{ :param1 => 3, :param2 => 2}] }
        colony.should_receive(:after_search)
        colony.get_ants
      end

      it "should log error if something's happened" do
        colony.stub(:search_ants){ raise }
        Log.logger_for.should_receive(:error).with(/Error while processing search ants for colony/)
        ants = colony.get_ants
      end
    end

    context "#is_it_me?" do
      it "should return true if all params matches" do
        colony.is_it_me?({"type"=> "type", "a" => 1}).should be_true
      end
      it "should return false if at least one param doesn't match" do
        colony.is_it_me?({"type"=> "type", "a" => 2}).should be_false
      end
    end

    context "#not_finished" do
      it "should return not finished ants" do
        ant1 = double("ant1")
        ant2 = double("ant2")
        ant3 = double("ant3")
        ant4 = double("ant4")
        ant1.stub(:finished?){true}
        ant2.stub(:finished?){false}
        ant3.stub(:finished?){true}
        ant4.stub(:finished?){true}
        colony.stub(:ants){ [ant1, ant2, ant3, ant4] }
        colony.not_finished.should eql([ant1, ant3, ant4])
      end

    end
    context "#type" do
      it "should return type from params" do
        colony.params['type'].should eql("type")
      end
    end


  end
end
