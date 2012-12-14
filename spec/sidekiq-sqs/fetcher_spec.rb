require 'spec_helper'

class FetcherStub
  def fetch
  end

  def initialize(mgr, queues, strict)
    @mgr, @queues, @strictly_ordered_queues = mgr, queues, strict
  end

  include Sidekiq::Sqs::Fetcher
end

describe Sidekiq::Sqs::Fetcher do
  let(:manager) { stub }
  let(:queues) { [] }
  let(:queue) { stub }

  before { Sidekiq.stubs(sqs: stub(queues: stub(named: queue))) }

  subject { FetcherStub.new(manager, queues, strict) }
  context "in strict mode" do
    let(:strict) { true }

    describe "#fetch_single_message" do
      it "returns a message if found" do
        queue.stubs(receive_message: :message)

        subject.fetch_single_message(:queue).should eq(:message)
      end

      it "returns nil if no messages found when not processing" do
        queue.stubs(receive_message: nil, invisible_messages: 0)

        subject.fetch_single_message(:queue).should be_nil
      end

      it "raises an error if no messages found when processing" do
        queue.stubs(receive_message: nil, invisible_messages: 1)

        expect do
          subject.fetch_single_message(:queue)
        end.to raise_error(Sidekiq::Sqs::Fetcher::QueueNotDoneError)
      end
    end
  end

  context "in not strict mode" do
    let(:strict) { false }
    describe "#fetch_single_message" do
      it "returns nil if no messages and processing" do
        queue.stubs(receive_message: nil, invisible_messages: 1)

        subject.fetch_single_message(:queue).should be_nil
      end
    end
  end
end
