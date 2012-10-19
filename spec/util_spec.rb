require 'spec_helper'

class UtilTest
  include Sidekiq::Util
end

require 'sidekiq-sqs/util'

describe Sidekiq::Util do
  subject { UtilTest.new }

  describe ".constantize" do
    it "uses activesupport" do
      klass = "UtilTest"
      klass.expects(:constantize).returns(:run)

      subject.constantize(klass).should eq(:run)
    end

  end
end
