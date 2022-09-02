# frozen_string_literal: true

require "spec_helper"

RSpec.describe Retroactivity::LoggedChange do
  subject(:logged_change) do
    described_class.create!(
      :loggable => loggable,
      :data => data,
      :as_of => Time.now
    )
  end

  before do
    stub_const("TestKlass", loggable_klass)

    ActiveRecord::Base.connection.create_table :test_klasses do |t|
      t.string :foo
      t.integer :bar
    end
  end

  after { ActiveRecord::Base.connection.drop_table :test_klasses }

  let(:loggable_klass) do
    Class.new(ActiveRecord::Base) do
      include Retroactive
    end
  end

  let(:loggable) do
    loggable_klass.create!(:foo => "hello", :bar => 6)
  end

  describe "#apply!" do
    context "when the source value of the change matches the current state of the loggable object" do
      let(:data) { { "foo" => ["hello", "heo"], "bar" => [6, nil] } }

      it "applies the attribute changes" do
        expect { logged_change.apply! }
          .to change { loggable.foo }.from("hello").to("heo")
          .and change { loggable.bar }.from(6).to(nil)
      end
    end

    context "when the source value of the change does not match the current state of the loggable object" do
      let(:data) { { "foo" => ["hello", "heo"], "bar" => [nil, 6] } }

      it "raises an error" do
        expect { logged_change.apply! }.to raise_error(described_class::CannotApplyError)
      end
    end
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

      it "raises an error" do
        expect { logged_change.unapply! }.to raise_error(described_class::CannotApplyError)
      end
    end
  end
end
