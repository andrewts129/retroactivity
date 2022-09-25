# frozen_string_literal: true

require "spec_helper"

RSpec.describe Retroactive do
  subject(:test_klass) do
    Class.new(ActiveRecord::Base) do
      include Retroactive
    end
  end

  before do
    stub_const("TestKlass", test_klass)

    Timecop.travel(Date.new(2022, 1, 1))
    ActiveRecord::Base.connection.create_table :test_klasses do |t|
      t.string :foo
      t.integer :bar
    end
  end

  after do
    ActiveRecord::Base.connection.drop_table :test_klasses
    Timecop.return
  end

  let(:now) { Time.now }
  let!(:instance) { Timecop.freeze(now - 5.days) { test_klass.create!(:foo => "bar") } }

  describe ".as_of" do
    subject(:state_as_of) { test_klass.as_of(as_of_time) }

    let(:as_of_time) { now - 3.days }
    let!(:instance2) { Timecop.freeze(now - 8.days) { test_klass.create!(:foo => "baz", :bar => 42) } }

    before do
      Timecop.freeze(now - 4.day) { instance.update!(:foo => "bar2") }
      Timecop.freeze(now - 2.days) { instance.update!(:foo => "bar3") }
      Timecop.freeze(now - 1.days) { instance.update!(:foo => "bar4", :bar => 8) }

      Timecop.freeze(now - 5.days) { instance2.update!(:foo => "baz2") }
    end

    it "returns a view of the database as it was at that time" do
      expect(state_as_of.map(&:attributes)).to contain_exactly(
        { "id" => instance.id, "foo" => "bar2", "bar" => nil },
        { "id" => instance2.id, "foo" => "baz2", "bar" => 42 }
      )
    end
  end

  describe "#as_of!" do
    subject(:as_of!) { instance.as_of!(as_of_time) }

    shared_examples_for "does nothing" do
      it "does not modify any attributes" do
        expect { as_of! }.not_to change { instance }
      end
    end

    context "when going into the past" do
      let(:as_of_time) { now - 3.days }

      context "when the object has not been mutated yet" do
        it_behaves_like "does nothing"

        context "when going back to before the object was created" do
          let(:as_of_time) { now - 10.days }

          it "sets everything to nil" do
            expect { as_of! }
              .to change { instance.id }.to(nil)
              .and change { instance.foo }.from("bar").to(nil)
              .and not_change { instance.bar }
          end
        end
      end

      context "when the object has been mutated" do
        before do
          Timecop.freeze(now - 4.day) { instance.update!(:foo => "bar2") }
          Timecop.freeze(now - 2.days) { instance.update!(:foo => "bar3") }
          Timecop.freeze(now - 1.days) { instance.update!(:foo => "bar4", :bar => 8) }
        end

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
      end
    end

    context "when going into the future" do
      let(:as_of_time) { now + 5.days }

      context "when the object has not been mutated yet" do
        it_behaves_like "does nothing"
      end

      context "when the object has been mutated" do
        before do
          Timecop.freeze(now - 4.day) { instance.update!(:foo => "bar2") }
          Timecop.freeze(now - 2.days) { instance.update!(:foo => "bar3") }
          Timecop.freeze(now - 1.days) { instance.update!(:foo => "bar4", :bar => 8) }
        end

        it_behaves_like "does nothing"

        context "when some of the mutations have been rolled back" do
          before { instance.as_of!(now - 3.days) }

          context "and going to the future" do
            it "brings it back to the current state" do
              expect { as_of! }
                .to change { instance.foo }.from("bar2").to("bar4")
                .and change { instance.bar }.from(nil).to(8)
            end
          end

          context "and going to the present" do
            let(:as_of_time) { now }

            it "brings it back to the current state" do
              expect { as_of! }
                .to change { instance.foo }.from("bar2").to("bar4")
                .and change { instance.bar }.from(nil).to(8)
            end
          end

          context "and staying in the past, but moving forward" do
            let(:as_of_time) { now - 1.days - 5.hours }

            it "goes to the correct state" do
              expect { as_of! }
                .to change { instance.foo }.from("bar2").to("bar3")
                .and not_change { instance.bar }
            end
          end
        end
      end
    end
  end

  describe "#as_of" do
    subject(:instance_as_of) { instance.as_of(as_of_time) }

    shared_examples_for "does not mutate the original instance" do
      it "does not mutate the original instance" do
        expect { instance_as_of }.not_to change { instance }
      end
    end

    before do
      Timecop.freeze(now - 4.day) { instance.update!(:foo => "bar2") }
      Timecop.freeze(now - 2.days) { instance.update!(:foo => "bar3") }
      Timecop.freeze(now - 1.days) { instance.update!(:foo => "bar4", :bar => 8) }
    end

    context "when going backward in time" do
      let(:as_of_time) { now - 3.days }

      it_behaves_like "does not mutate the original instance"

      it "returns a copy of the object as it was at that time" do
        expect(instance_as_of).to be_a(instance.class)
        expect(instance_as_of).to have_attributes(
          :id => instance.id,
          :foo => "bar2",
          :bar => nil
        )
      end

      context "when the object was already rolled back some" do
        before { instance.as_of!(now - 1.day) }

        it "still returns a copy of the object as it was at that time" do
          expect(instance_as_of).to be_a(instance.class)
          expect(instance_as_of).to have_attributes(
            :id => instance.id,
            :foo => "bar2",
            :bar => nil
          )
        end
      end

      context "when the object has been rolled forward" do
        before { instance.as_of!(now + 3.days) }

        it "still returns a copy of the object as it was at that time" do
          expect(instance_as_of).to be_a(instance.class)
          expect(instance_as_of).to have_attributes(
            :id => instance.id,
            :foo => "bar2",
            :bar => nil
          )
        end
      end

      context "when going to before the object was initialized" do
        let(:as_of_time) { now - 10.days }

        it "returns an object with all nil values" do
          expect(instance_as_of).to be_a(instance.class)
          expect(instance_as_of).to have_attributes(
            :id => nil,
            :foo => nil,
            :bar => nil
          )
        end
      end
    end

    context "when going forward in time" do
      let(:as_of_time) { now + 5.days }

      it_behaves_like "does not mutate the original instance"

      context "when the object was already rolled back some" do
        before { instance.as_of!(now - 1.day) }

        it_behaves_like "does not mutate the original instance"

        it "returns a copy of the object as it is in the present" do
          expect(instance_as_of).to be_a(instance.class)
          expect(instance_as_of.attributes).to eq(instance.attributes)
        end
      end

      context "when the object was already forward back some" do
        before { instance.as_of!(now + 1.day) }

        it_behaves_like "does not mutate the original instance"

        it "returns a copy of the object as it is in the present" do
          expect(instance_as_of).to be_a(instance.class)
          expect(instance_as_of.attributes).to eq(instance.attributes)
        end
      end
    end
  end

  describe "updates" do
    it "logs on saves" do
      expect { instance.update!(:foo => "baz") }.to change { instance.logged_changes.count }.from(1).to(2)
      expect(instance.foo).to eq("baz")
    end

    context "when the object has been rolled back" do
      before do
        Timecop.freeze(now - 4.day) { instance.update!(:foo => "bar2") }
        Timecop.freeze(now - 2.days) { instance.update!(:foo => "bar3") }
        Timecop.freeze(now - 1.days) { instance.update!(:bar => 8) }
      end

      shared_examples_for "makes updates retroactively" do
        subject(:update!) { rolled_back_instance.update!(:foo => "hello", :bar => 3) }

        let(:as_of_time) { now - 1.day - 5.hours }

        it "updates attributes that are not overriden both at the frozen time and in the present" do
          expect { update! }
            .to change { rolled_back_instance.foo }.from("bar3").to("hello")

          expect(TestKlass.find(instance.id).foo).to eq("hello")
        end

        it "updates attributes that are overriden only at the frozen time and not in the present" do
          expect { update! }
            .to change { rolled_back_instance.bar }.from(nil).to(3)

          expect(TestKlass.find(instance.id).bar).to eq(8)
        end
      end

      context "with as_of!" do
        subject(:rolled_back_instance) { instance }

        before { rolled_back_instance.as_of!(as_of_time) }

        it_behaves_like "makes updates retroactively"
      end

      context "with as_of" do
        subject(:rolled_back_instance) { instance.as_of(as_of_time) }

        it_behaves_like "makes updates retroactively"
      end
    end

    context "when the object has been rolled forward" do
      subject(:update!) { rolled_forward_instance.update!(:foo => "hello", :bar => 3) }

      let(:as_of_time) { now + 5.days }

      shared_examples_for "realizes it's a future dated update" do
        it "raises CannotMakeFutureDatedUpdatesError" do
          expect { update! }.to raise_error(Retroactivity::CannotMakeFutureDatedUpdatesError)
        end
      end

      context "with as_of!" do
        subject(:rolled_forward_instance) { instance }

        before { rolled_forward_instance.as_of!(as_of_time) }

        it_behaves_like "realizes it's a future dated update"
      end

      context "with as_of" do
        subject(:rolled_forward_instance) { instance.as_of(as_of_time) }

        it_behaves_like "realizes it's a future dated update"
      end
    end
  end
end
