require 'spec_helper'

Sidekiq::Util.send :include, Sidekiq::Sqs::Util
class UtilTest
  include Sidekiq::Util
end

describe Sidekiq::Sqs::Util do
  subject { UtilTest.new }

  describe ".constantize" do
    it "uses activesupport" do
      klass = "UtilTest"
      klass.expects(:constantize).returns(:run)

      subject.constantize(klass).should eq(:run)
    end

  end
end
