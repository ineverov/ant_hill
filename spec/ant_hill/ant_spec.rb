require 'spec_helper'

module AntHill
  describe Ant do
    let(:ant){Ant.new("name", AntColony.new, Configuration.config, {:a => 1, :b => 2})}
    context "#matches?" do
      it "should match with default proc" do
        ant.matches?({:a => 1, :b =>2, :c => 3}).should be_true
        ant.matches?({:a => 1, :c => 3}).should be_false
      end
    end
    context "#param_match?" do
      it "should match single param" do
        ant.param_matches?(:a, 1).should be_true
      end
    end
    context "#priority" do
      it "should return priority" do
        ant.priority({:a => 2}).should be_a(Float)
      end
      it "should return higher priority if params matches" do
        ant.priority({:a => 1}).should > ant.priority({:a => 2})
        ant.priority({:a => 1, :b => 2}).should > ant.priority({:a => 1, :b => 1})
      end
    end
  end
end
