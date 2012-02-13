require 'spec_helper'
module AntHill
  describe Configuration do
    let(:config) { Configuration.config(File.dirname( __FILE__ )+"/../support/config.yml") }
    it "should return same object" do
      config === Configuration.config
    end
    it "should require libs" do
      defined?(Configuration::AntHillExtension).should be_true
    end
    context "#match_proc_for_param" do
      it "should return match proc for param" do
        config.match_proc_for_param(:brand).should be_true
      end
    end
  end
end
