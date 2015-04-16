module AwsDot

  class Stack

    attr_reader :name

    def initialize(name, dir)
      @name = name
      @dir = dir
    end

    def resources
      @resources ||= load_file("resources.json")["StackResourceSummaries"]
    end

    def template
      @template ||= load_file "template.json"
    end

    def description
      @description ||= load_file("description.json")["Stacks"][0]
    end

    def get_physical_id(r)
      resources.each do |res|
        return res["PhysicalResourceId"] if res["LogicalResourceId"] == r
      end
      nil
    end

    def actual_parameters
      @actual_parameters ||= description["Parameters"].reduce({}) do |h, p|
        h[ p["ParameterKey"] ] = p["ParameterValue"]
        h
      end
    end

    def get_parameter_value(k)
      actual_parameters[k]
    end

    def guess_env
      m = name.match /^(?<env>int|test|live)-/
      m ||= name.match /^(?<env>Int|Test|Live)[A-Z]/
      m ||= name.match /^Sky(?<env>Test|Live)/
      return m["env"].downcase if m
      nil
    end

    def actors
      AwsDot::StackActorCollection.new(self)
    end

    private

    def load_file(file)
      JSON.parse(IO.read "#{@dir}/#{file}")
    end

  end

end
