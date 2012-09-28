require 'spec_helper'

describe Sidekiq::Sqs::Middleware::Compression do
  context "Server" do
    subject { Sidekiq::Sqs::Middleware::Compression::Server.new }
    let(:message) { stub(body: "eJzLTS0uTkxPBQALwQLm\n") }

    it "decompresses the message" do
      subject.call(nil, message, nil)

      message.body.should eq('message')
    end
  end

#  context "Client" do
#    subject { Sidekiq::Sqs::Middleware::Compression::Client.new }
#    let(:message) { 'message' }
#
#    it "compresses the message and yields" do
#      expect {|b| subject.call(nil, message, :queue, &b) }.to yield_control 
#
#      message.should eq(Base64.encode64(Zlib::Deflate.deflate('message')))
#    end
#  end
end

