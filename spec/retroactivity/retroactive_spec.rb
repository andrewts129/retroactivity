require "spec_helper"

RSpec.describe Retroactive do
  subject(:test_klass) do
    class TestKlass < ActiveRecord::Base
      include Retroactive
    end
  end

  before(:all) do 
    ActiveRecord::Base.connection.create_table :test_klasses do |t|
      t.string :foo
    end
  end

  after(:all) { ActiveRecord::Base.connection.drop_table :test_klasses }

  let(:instance) { test_klass.create!(:foo => "bar") }

  it "logs on saves" do
    expect { instance.update!(:foo => "baz") }.to change { instance.logged_changes.count }.from(1).to(2)
    expect(instance.foo).to eq("baz")
  end
end
