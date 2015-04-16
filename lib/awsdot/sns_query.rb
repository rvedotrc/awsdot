module AwsDot

  class SNSQuery

    # The SUBSCRIPTIONS file contains a dump of all SNS subscriptions (as dumped by "aws sns list-subscriptions")
    SUBSCRIPTIONS = "/Users/rachel/git/git.reith.rve.org.uk/aws-query/accounts/bbc-production/sns/list-subscriptions.json"

    def self.subscriptions
      @subscriptions ||= JSON.load(IO.read SUBSCRIPTIONS)["Subscriptions"]
    end

  end

end
