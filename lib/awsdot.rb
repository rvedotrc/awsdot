require 'json'

# Usage:
# - ensure the require json files are available (see STACKS_DIR and
# SUBSCRIPTIONS, below)
# Produce the digraph dot file:
#   ruby lib/awsdot.rb > aws.dot
# Render the dot as (e.g.) png:
#   dot -Tpng -o aws.png aws.dot

module AwsDot

  class StackCollection

    include Enumerable

    # STACKS_DIR should contain one subdir for each stack you want to analyze,
    # where each subdir contains resources.json, template.json and
    # description.json (as produced by the 'aws' command line tool).
    STACKS_DIR = "/Users/rachel/git/git.reith.rve.org.uk/cloudformation-mirror/accounts/bbc-production/stacks"

    def each
      Dir.entries(STACKS_DIR).each do |n|
        unless n.start_with? "."
          yield Stack.new(n, "#{STACKS_DIR}/#{n}")
        end
      end
    end

  end

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

    private

    def load_file(file)
      JSON.parse(IO.read "#{@dir}/#{file}")
    end

  end

  class SNSQuery

    # The SUBSCRIPTIONS file contains a dump of all SNS subscriptions (as dumped by "aws sns list-subscriptions")
    SUBSCRIPTIONS = "/Users/rachel/git/git.reith.rve.org.uk/aws-query/accounts/bbc-production/sns/list-subscriptions.json"

    def self.subscriptions
      @subscriptions ||= JSON.load(IO.read SUBSCRIPTIONS)["Subscriptions"]
    end

  end

end

def dot_string(s)
  s.inspect
end

def render_digraph(nodes, edges)
  puts "digraph aws {"

  nodes.entries.sort_by(&:first).each do |k,v|
    print "  %s" % k
    unless v.empty?
      print " [ #{v.entries.sort_by(&:first).map do |vk, vv|
        %Q[#{vk}=#{dot_string(vv)}]
      end.join ", "} ]"
    end
    print "\n"
  end

  edges.entries.sort_by(&:first).each do |k,v|
    print "  %s -> %s" % k
    unless v.empty?
      print " [ #{v.entries.sort_by(&:first).map do |vk, vv|
        %Q[#{vk}=#{dot_string(vv)}]
      end.join ", "} ]"
    end
    print "\n"
  end

  puts "}"
end

def policy_applies_to(policy_properties, actor_resource_type, actor_name)
  roles = policy_properties["Roles"] || []
  roles = [ roles ] unless roles.kind_of? Array
  return true if roles.any? {|r| r.kind_of? Hash and r["Ref"] == actor_name }

  users = policy_properties["Users"] || []
  users = [ users ] unless users.kind_of? Array
  return true if users.any? {|r| r.kind_of? Hash and r["Ref"] == actor_name }

  false
end

nodes = {}
edges = {}

AwsDot::StackCollection.new.each do |stack|
  if stack.guess_env == "live"
    if stack.name.match /modav|mami|sky|housekeep/i
      #users = stack.resources.select {|r| r["ResourceType"] == "AWS::IAM::User"}
      #roles = stack.resources.select {|r| r["ResourceType"] == "AWS::IAM::Role"}
      #puts "%4d  %4d  %s" % [ users.count, roles.count, stack.name ]
      stack.resources.entries.sort_by(&:first).each do |r|
        if r["ResourceType"].match /^AWS::IAM::(User|Role)$/
          node_name = r["PhysicalResourceId"].gsub "-", "_"
          nodes[node_name] = {
            label: "#{stack.name}\n#{r["LogicalResourceId"]}",
            shape: "ellipse",
            color: "blue",
          }

          # Load the template of the same stack and look for AWS::IAM::Policy
          # which are applied to this role or user.
          statements = []
          policies = stack.template["Resources"].entries.sort_by(&:first).each do |k, v|
            if v["Type"] == "AWS::IAM::Policy"
              if policy_applies_to(v["Properties"], r["ResourceType"], r["LogicalResourceId"])
                statements.concat v["Properties"]["PolicyDocument"]["Statement"]
              end
            end
          end

          # puts "Statements that apply to #{r["LogicalResourceId"]}"
          # puts JSON.pretty_generate(statements)

          # Find out what resources these roles grant access to.
          # Initially don't care about direction; see what weight=0 looks
          # like.

          statements.select {|stmt| stmt["Effect"] == "Allow"}.each do |stmt|
            resources = stmt["Resource"] || []
            resources = [ resources ] unless resources.kind_of? Array
            resources.each do |res|
              # puts "#{stack.name} #{r["LogicalResourceId"]} has some sort of access to #{res.inspect}"

              if res.kind_of? Hash and res.has_key? "Ref"
                ref = res["Ref"]
                if((stack.template["Parameters"] || {})[ref])
                  res = stack.get_parameter_value(ref)
                elsif stack.template["Resources"][ref]
                  res = stack.get_physical_id(ref)
                end
              end

              puts "// #{stack.name} #{r["LogicalResourceId"]} has some sort of access to #{res.inspect}"

              if res.kind_of? String and res.match /^arn:aws:sqs:/ and !res.match /((DeadLetter|BadMessage|Fail)Queue|BadMsg|Failed)/
                queue_name = res.split(/:/).last
                res_node_name = res.gsub /\W/, "_"

                nodes[res_node_name] = {
                  label: queue_name.sub(/-[A-Z0-9]{6,20}$/, "").gsub("-", "\n"),
                  shape: "rect",
                }

                if stmt["Action"].include? "sqs:SendMessage"
                  edges[[node_name, res_node_name]] = {
                  }
                end
                if stmt["Action"].include? "sqs:DeleteMessage"
                  edges[[res_node_name, node_name]] = {
                  }
                end
              end

              if res.kind_of? String and res.match /^arn:aws:sns:/
                topic_name = res.split(/:/).last
                res_node_name = res.gsub /\W/, "_"

                nodes[res_node_name] = {
                  label: topic_name.sub(/-[A-Z0-9]{6,20}$/, "").gsub("-", "\n"),
                  shape: "rect",
                  fontcolor: "red",
                }

                if stmt["Action"].include? "sns:Publish"
                  edges[[node_name, res_node_name]] = {
                  }
                end
              end
            end
          end

          # Care about: queues (but not error queues), topics, buckets,
          # simpledb, dynamodb.
        end
      end
    end
  end
end

AwsDot::SNSQuery.subscriptions.each do |sub|
  next unless sub["Protocol"] == "sqs"
  next unless sub["TopicArn"].match /:(Sky)?live/i
  next unless sub["TopicArn"].match /modav|mami|sky|housekeep/i
  next if sub["Endpoint"].match /(Turncoat|Rorschach)Resources-Queue/
  next if sub["Endpoint"].match /-i-/
  next unless sub["Endpoint"].match /modav|mami|sky|housekeep/i

  puts "// sns #{sub["TopicArn"]} -> #{sub["Endpoint"]}"

  topic_name = sub["TopicArn"].split(/:/).last
  topic_node_name = sub["TopicArn"].gsub /\W/, "_"
  queue_name = sub["Endpoint"].split(/:/).last
  queue_node_name = sub["Endpoint"].gsub /\W/, "_"

  edges[[topic_node_name, queue_node_name]] = {
  }
end

render_digraph nodes, edges
