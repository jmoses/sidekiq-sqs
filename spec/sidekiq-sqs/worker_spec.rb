require 'spec_helper'

class StubWorker
  include Sidekiq::Sqs::Worker
end

describe Sidekiq::Sqs::Worker do
  subject { StubWorker.new }

  describe "#perform_async_bulk" do
    it "formats the arguments" do
      subject.expects(:client_push_bulk).with('class' => subject, 'args' => :args)

      subject.perform_async_bulk(:args)
    end
  end

  describe "#client_push_bulk" do
    it "delegates to Client" do
      Sidekiq::Client.expects(:push_bulk).with(:args)

      subject.client_push_bulk(:args)
    end
  end
end
