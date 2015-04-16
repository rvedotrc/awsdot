module AwsDot

  class Actor

    attr_reader :stack

    def initialize(stack, resource)
      @stack = stack
      @resource = resource
    end

    def node_id
      @resource["PhysicalResourceId"].gsub "-", "_"
    end

    def logical_resource_id
      @resource["LogicalResourceId"]
    end

    def resource_type
      @resource["ResourceType"]
    end

    def policy_statements
      statements = []

      policies = stack.template["Resources"].entries.sort_by(&:first).each do |k, v|
        if v["Type"] == "AWS::IAM::Policy"
          if policy_applies_to_me(v["Properties"])
            statements.concat v["Properties"]["PolicyDocument"]["Statement"]
          end
        end
      end

      statements
    end

    private

    def policy_applies_to_me(policy_properties)
      roles = policy_properties["Roles"] || []
      roles = [ roles ] unless roles.kind_of? Array
      return true if roles.any? {|r| r.kind_of? Hash and r["Ref"] == logical_resource_id }

      users = policy_properties["Users"] || []
      users = [ users ] unless users.kind_of? Array
      return true if users.any? {|r| r.kind_of? Hash and r["Ref"] == logical_resource_id }

      false
    end

  end

end
