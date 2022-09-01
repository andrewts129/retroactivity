require "spec_helper"

RSpec.describe Retroactivity::LoggedChange do
  subject(:logged_change) do
    described_class.create!(
      :loggable => loggable,
      :operation => described_class::Operation::UPDATE,
      :data => data,
      :as_of => Time.now
    )
  end


  before(:all) do 
    ActiveRecord::Base.connection.create_table :test_klasses do |t|
      t.string :foo
      t.integer :bar
    end
  end

  after(:all) { ActiveRecord::Base.connection.drop_table :test_klasses }

  let(:loggable) do
    class TestKlass < ActiveRecord::Base
      include Retroactive
    end

    TestKlass.create!(:foo => "hello", :bar => 6)
  end

  describe "#unapply!" do
    context "when the target value of the change matches the current state of the loggable object" do
      let(:data) { { "foo" => ["heo", "hello"], "bar" => [nil, 6] } }

      it "rolls back the object's attributes" do
        expect { logged_change.unapply! }
          .to change { loggable.foo }.from("hello").to("heo")
          .and change { loggable.bar }.from(6).to(nil)
      end
    end

    context "when the target value of the change does not match the current state of the loggable object" do
      let(:data) { { "foo" => ["heo", "hello"], "bar" => [nil, 7] } }

      it "rolls back the object's attributes" do
        expect { logged_change.unapply! }.to raise_error(described_class::CannotUnapplyError)
      end
    end
  end
end
