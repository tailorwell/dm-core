require 'spec_helper'

describe "Scoped options" do
  before :all do
    DataMapper.setup(:default, :adapter => :in_memory, :a => 'b')

    class ::Jabberwock
      include DataMapper::Resource

      property :id,        Serial
      property :color,     String
      property :num_spots, Integer
      property :striped,   Boolean
    end

    DataMapper.finalize

    Jabberwock.create(:color => 'red', :striped => true)
    Jabberwock.create(:color => 'blue', :striped => true)
    Jabberwock.create(:color => 'green', :striped => false)
    @options1 = {:foo => "bar"}
    @options2 = {:foo => "not bar"}
  end
  it "should run" do
    DataMapper.repository(:default, @options1) do
      @striped = Jabberwock.all(:striped => true)
    end
    DataMapper.repository(:default, @options2) do
      @red = Jabberwock.all
    end
    puts @red.length
    require 'pry'
    binding.pry
    puts @striped.length   #should run the first query - but will it have it's own options or those of options2
  end
end