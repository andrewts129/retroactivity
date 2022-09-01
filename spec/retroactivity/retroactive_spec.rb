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
      t.integer :bar
    end
  end

  after(:all) { ActiveRecord::Base.connection.drop_table :test_klasses }

  let(:instance) { Timecop.freeze(Date.new(2022, 1, 4)) { test_klass.create!(:foo => "bar") } }

  it "logs on saves" do
    expect { instance.update!(:foo => "baz") }.to change { instance.logged_changes.count }.from(1).to(2)
    expect(instance.foo).to eq("baz")
  end

  describe "#rewind!" do
    subject(:rewind!) { instance.rewind!(as_of) }

    before do
      Timecop.freeze(Date.new(2022, 1, 5)) { instance.update!(:foo => "bar2") }
      Timecop.freeze(Date.new(2022, 1, 7)) { instance.update!(:foo => "bar3") }
      Timecop.freeze(Date.new(2022, 1, 8)) { instance.update!(:foo => "bar4", :bar => 8) }
    end

    let(:as_of) { Date.new(2022, 1, 6) }

    it "sets the attributes back to what they were at as_of" do
      expect { rewind! }
        .to change { instance.foo }.from("bar4").to("bar2")
        .and change { instance.bar }.from(8).to(nil)
    end

    context "when going back to before the object was created" do
      let(:as_of) { Date.new(2022, 1, 1) }

      it "sets everything to nil" do
        expect { rewind! }
          .to change { instance.id }.to(nil)
          .and change { instance.foo }.from("bar4").to(nil)
          .and change { instance.bar }.from(8).to(nil)
      end
    end
  end
end
