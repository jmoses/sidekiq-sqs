require 'spec_helper'

class StubProcessor
  def process(msg, queue)
  end

  def stats(*args)
    raise RuntimeError.new
  end

  include Sidekiq::Sqs::Processor
end

describe Sidekiq::Sqs::Processor do
  subject { StubProcessor.new }

  describe "#process_with_sqs" do
    let(:body) { "eJxLTEo2NDIGAAbsAb0=\n" }
    let(:message) { stub(body: body) }
    let(:queue) { stub }

    it "expands the message, delegates to the base class and deletes the message" do
      subject.expects(:process_without_sqs).with('abc123', queue).returns(:processed)
      message.expects(:delete)

      subject.process(message, queue).should eq(:processed)
    end
  end

  describe "#stats" do
    it "just yields" do
      expect {|b| subject.stats(&b) }.to yield_control
    end
  end
end
