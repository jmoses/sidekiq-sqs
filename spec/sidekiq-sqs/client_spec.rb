require 'spec_helper'

class StubClient
  def self.push(*args)
  end

  def self.push_bulk(*args)
  end

  def self.process_single(*args)
  end

  include Sidekiq::Sqs::Client
end

describe Sidekiq::Sqs::Client do
  subject { StubClient }

  describe ".process_single_with_sqs" do
    it "base64 encodes and compresses the payload" do
      subject.expects(:process_single_without_sqs).with(:worker_class, :item).returns([:item, "payload"])

      subject.process_single_with_sqs(:worker_class, :item).should eq([:item, "eJwrSKzMyU9MAQAL3QLr\n"])
    end
  end

  describe ".queue_or_create" do
    let(:queue) { 'queue' }
    let(:queues) { stub }
    before { Sidekiq.stubs(sqs: stub(queues: queues)) }

    it "returns the queue if it exists" do
      queues.expects(:named).with(queue).returns(:queue)

      subject.queue_or_create(queue).should eq(:queue)
    end

    it "creates the queue if it doesn't exists" do
      queues.expects(:named).with(queue).raises(AWS::SQS::Errors::NonExistentQueue.new)
      queues.expects(:create).with(queue).returns(:queue)

      subject.queue_or_create(queue).should eq(:queue)
    end
  end
end
