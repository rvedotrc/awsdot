module AwsDot

  class StackActorCollection

    include Enumerable

    attr_reader :stack

    def initialize(stack)
      @stack = stack
    end

    def each
      stack.resources.entries.sort_by(&:first).each do |r|
        if r["ResourceType"].match /^AWS::IAM::(User|Role)$/
          actor = AwsDot::Actor.new(stack, r)
          yield actor
        end
      end
    end

  end

end
