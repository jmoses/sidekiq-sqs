require 'spec_helper'

describe Sidekiq::Sqs::QueueManager do
  let(:queues) { [] }
  let(:sqs_queues) { [] }
  let(:strict) { false }
  subject { described_class.new(queues, strict) }

  before do
    described_class.any_instance.stubs(queue_named: nil, all_remote_queues: [])  
  end

  describe ".initialize" do
    it "initializes!" do
      described_class.any_instance.expects(:initialize!)
      subject
    end
  end

  describe "#initialize!" do
    it "parses and updates" do
      subject.expects(:parse_wildcards!)
      subject.expects(:update!)

      subject.send(:initialize!)
    end
  end

  describe "#parse_wildcards!" do
    it "parses and counts properly" do
      queues.concat %w( a a b b c* d* e* e* )
      subject.send(:parse_wildcards!)

      subject.wildcard_patterns.should eq('c*' => 1, 'd*' => 1, 'e*' => 2)
    end
  end
end
