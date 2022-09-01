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

  before { Timecop.travel(Date.new(2022, 1, 1)) }
  after { Timecop.return }

  let(:now) { Time.now }
  let(:instance) { Timecop.freeze(now - 5.days) { test_klass.create!(:foo => "bar") } }

  it "logs on saves" do
    expect { instance.update!(:foo => "baz") }.to change { instance.logged_changes.count }.from(1).to(2)
    expect(instance.foo).to eq("baz")
  end

  describe "#as_of!" do
    subject(:as_of!) { instance.as_of!(as_of_time) }

    before do
      Timecop.freeze(now - 4.day) { instance.update!(:foo => "bar2") }
      Timecop.freeze(now - 2.days) { instance.update!(:foo => "bar3") }
      Timecop.freeze(now - 1.days) { instance.update!(:foo => "bar4", :bar => 8) }
    end

    let(:as_of_time) { now - 3.days }

    it "sets the attributes back to what they were at that time" do
      expect { as_of! }
        .to change { instance.foo }.from("bar4").to("bar2")
        .and change { instance.bar }.from(8).to(nil)
    end

    context "when going back to before the object was created" do
      let(:as_of_time) { now - 10.days }

      it "sets everything to nil" do
        expect { as_of! }
          .to change { instance.id }.to(nil)
          .and change { instance.foo }.from("bar4").to(nil)
          .and change { instance.bar }.from(8).to(nil)
      end
    end

    context "when travelling into the future" do
      let(:as_of_time) { now + 5.days }

      it "raises an error" do
        expect { as_of! }.to raise_error(NotImplementedError)
      end
    end
  end
end
