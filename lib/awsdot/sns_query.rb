module AwsDot

  class SNSQuery

    # The SUBSCRIPTIONS file contains a dump of all SNS subscriptions (as dumped by "aws sns list-subscriptions")
    SUBSCRIPTIONS = "./list-subscriptions.json"

    def self.subscriptions
      @subscriptions ||= JSON.load(IO.read SUBSCRIPTIONS)["Subscriptions"]
    end

  end

end
