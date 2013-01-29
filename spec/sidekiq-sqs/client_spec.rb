require 'spec_helper'

class StubClient
  def self.push(*args)
  end

  def self.push_bulk(*args)
  end

  def self.process_single(*args)
  end

  def self.normalize_item(*args)
    Hash.new
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

  describe ".environmental_queue_name" do
    before do
      if defined?(::Rails)
        ::Rails.stubs(env: "test")
      else
        ::Rails = stub(env: "test")
      end
    end

    it "prepends the environment name" do
      subject.environmental_queue_name("queue").should eq("test_queue")
    end

    it "doesn't prepend if it's already prepended" do
      subject.environmental_queue_name("test_queue").should eq("test_queue")
    end
  end

  describe ".push" do

    context "when scheduling a job" do
      let(:item) { { 'class' => :klass } }

      it "dispatches to .send_message with delay_seconds" do
        normalized = { 'at' => Time.now.to_f + 900, 'jid' => 'abc123' }
        subject.expects(:normalize_item).with(item).returns(normalized)
        subject.expects(:process_single).with(:klass, normalized).returns([normalized, :payload])

        queue = mock { expects(:send_message).with(:payload, { delay_seconds: 900 }).returns(true) }
        subject.stubs(queue_or_create: queue)

        subject.push(item).should eq('abc123')
      end

      it "raises an error if the amount to delay is > 900 seconds" do
        normalized = { 'at' => Time.now.to_f + 901 }
        subject.expects(:normalize_item).with(item).returns(normalized)
        subject.expects(:process_single).with(:klass, normalized).returns([normalized, :payload])
        subject.stubs(:queue_or_create)

        expect { subject.push(item) }.to raise_error
      end

    end

    context "when queueing a job normally" do
      let(:item) { { 'class' => :klass } }
      let(:queue) { mock { expects(:send_message).with(:payload) } }

      it "dispatches to .send_message" do
        subject.expects(:normalize_item).with(item).returns(:normalized)
        subject.expects(:process_single).with(:klass, :normalized).returns([:normalized, :payload])
        subject.stubs(queue_or_create: queue)

        subject.push(item)
      end
    end
  end

  describe ".bulk_send_to_sqs" do
    let(:retryable) do
      {:error_code => 'ServiceUnavailable', :message_body => "blarg"}
    end
    let(:failed) do
      {:error_code => "GFYS", :message_body => "and your little dog, too"}
    end
    it "dispatches to .send_batch_to_sqs in groups of 10" do
      items = 1.upto(20).to_a
      subject.expects(:send_batch_to_sqs).with(:queue, 1.upto(10).to_a).returns([[], []])
      subject.expects(:send_batch_to_sqs).with(:queue, 11.upto(20).to_a).returns([[], []])

      subject.bulk_send_to_sqs(:queue, items)
    end

    it "aggregates failed and retryable messages" do
      items = 1.upto(20).to_a
      subject.expects(:send_batch_to_sqs).with(:queue, 1.upto(10).to_a).returns([[failed], []])
      subject.expects(:send_batch_to_sqs).with(:queue, 11.upto(20).to_a).returns([[], [retryable]])

      subject.bulk_send_to_sqs(:queue, items).should eq([[failed], [retryable]])
    end
  end

  describe ".send_batch_to_sqs" do
    let(:queue) { stub }
    let(:retryable) do
      {:error_code => 'ServiceUnavailable', :message_body => "blarg"}
    end
    let(:failed) do
      {:error_code => "GFYS", :message_body => "and your little dog, too"}
    end

    it "dispatches to the queue" do
      queue.expects(:batch_send).with(:items)

      subject.send_batch_to_sqs(queue, :items).should eq([[], []])
    end

    it "aggregates errors correctly" do
      queue.expects(:batch_send).with(:items).raises(
        AWS::SQS::Errors::BatchSendError.new(
          [:sent],
          [failed, retryable]
        )
      )

      subject.send_batch_to_sqs(queue, :items).should eq([
        [failed], [retryable]
      ])
    end
  end

  describe ".push_bulk" do
    let(:queue) { stub }
    let(:retries) { [] }
    let(:fails) { [] }

    before do
      subject.stubs(queue_or_create: queue)
    end


    it "needs more tests"

    context "when some messages fail to insert" do
      before do
        subject.expects(:bulk_send_to_sqs).with(queue, :payloads).returns([fails, retries])
      end

      context "and all are retryable" do
        before do
          retries.push :error

          subject.expects(:format_items).with(:items).returns([:queue, :payloads])
        end

        it "retries" do
          subject.expects(:bulk_send_to_sqs).with(queue, [:error]).returns([[], []])

          subject.push_bulk(:items)
        end
      end

      context "and there are non-tryable failures" do
        before do
          fails.push :fail

          subject.expects(:format_items).with(:items).returns([:queue, :payloads])
        end

        it "raises an error" do
          expect { subject.push_bulk :items }.to raise_error(Sidekiq::Sqs::Client::BulkInsertionError)
        end
      end
    end
  end

  describe ".queue_or_create" do
    let(:queue) { 'queue' }
    let(:queues) { stub }
    before { Sidekiq.stubs(sqs: stub(queues: queues)) }

    it "returns the queue if it exists" do
      subject.expects(:environmental_queue_name).with(queue).returns(queue)
      queues.expects(:named).with(queue).returns(:queue)

      subject.queue_or_create(queue).should eq(:queue)
    end

    it "creates the queue if it doesn't exists" do
      subject.expects(:environmental_queue_name).with(queue).returns(queue)
      queues.expects(:named).with(queue).raises(AWS::SQS::Errors::NonExistentQueue.new)
      queues.expects(:create).with(queue).returns(:queue)

      subject.queue_or_create(queue).should eq(:queue)
    end
  end
end
