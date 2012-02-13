require 'spec_helper'

module AntHill
  describe AntColony do
    let(:colony){
      config = double("config")
      colony = AntColony.new( {:a => 1, :b => 2}, config )
      config.stub(:search_ants){ [ Ant.new("1",colony), Ant.new("2", colony)] }
      colony
    }
    context "#get_ants" do
      it "should add self params to all ants " do
        ants = colony.get_ants
        ants[rand(ants.size)].param_matches?(:a,1)
        ants[rand(ants.size)].param_matches?(:b,2)
      end
    end
  end
end
