require 'spec_helper'

module AntHill
  describe CreepModifier do
    context "#initialize" do
      it "should set @creep instance variable" do
        creep = double("creep")
        cm = CreepModifier.new(creep)
        cm.instance_variable_get(:@creep).should be_equal(creep)
      end
    end
    context "#find_diff" do
      let(:creep) {
        creep=double("creep")
        creep.stub(:current_params){ {'a' => '1', 'b' => '2', 'c'=> '3'} }
        creep
      }
      let(:ant){
        ant=double("ant")
        ant.stub(:params) { {'a'=>'2', "b" => '2', "d" => '5'} }
        ant.stub(:type) { 'a' }
        ant
      }
      it "should find params difference between creep and ant" do
        cm = CreepModifier.new(creep)
        cm.find_diff(ant).should eql({'a' => '2', 'd' => '5'})
      end
    end
  end 
end
