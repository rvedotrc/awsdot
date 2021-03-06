require 'json'

# Usage:
# - ensure the require json files are available (see STACKS_DIR and
# SUBSCRIPTIONS, below)
# Produce the digraph dot file:
#   ruby lib/awsdot.rb > aws.dot
# Render the dot as (e.g.) png:
#   dot -Tpng -o aws.png aws.dot

require_relative 'awsdot/stack_collection.rb'
require_relative 'awsdot/stack.rb'
require_relative 'awsdot/stack_actor_collection.rb'
require_relative 'awsdot/actor.rb'
require_relative 'awsdot/sns_query.rb'
require_relative 'awsdot/graph.rb'

def process_stack(stack)
  stack.actors.each do |actor|
    @graph.add_node actor.node_id, {
      label: "#{stack.name}\n#{actor.logical_resource_id}",
      shape: "ellipse",
      color: "blue",
    }

    process_actor actor
  end
end

def resolve_resource(stack, res)
  if res.kind_of? Hash and res.has_key? "Ref"
    ref = res["Ref"]
    if((stack.template["Parameters"] || {})[ref])
      res = stack.get_parameter_value(ref)
    elsif stack.template["Resources"][ref]
      res = stack.get_physical_id(ref)
    end
  end
  res
end

def process_policy_statement_resource(actor, stmt, res)
  node_name = actor.node_id

  res = resolve_resource(actor.stack, res)
  puts "// #{actor.stack.name} #{actor.logical_resource_id} has some sort of access to #{res.inspect}"

  # FIXME BBC-specific
  if res.kind_of? String and res.match /^arn:aws:sqs:/ and !res.match /((DeadLetter|BadMessage|Fail)Queue|Dlq|Badmsg|BadMsg|Failed)/
    queue_name = res.split(/:/).last
    res_node_name = res.gsub /\W/, "_"

    @graph.add_node res_node_name, {
      label: queue_name.sub(/-[A-Z0-9]{6,20}$/, "").gsub("-", "\n"),
      shape: "rect",
    }

    if stmt["Action"].include? "sqs:SendMessage" and stmt["Action"].include? "sqs:DeleteMessage"
      @graph.add_edge node_name, res_node_name, {
        dir: "both",
      }
    elsif stmt["Action"].include? "sqs:SendMessage"
      @graph.add_edge node_name, res_node_name, {
      }
    elsif stmt["Action"].include? "sqs:DeleteMessage"
      @graph.add_edge res_node_name, node_name, {
      }
    end
  end

  if res.kind_of? String and res.match /^arn:aws:sns:/
    topic_name = res.split(/:/).last
    res_node_name = res.gsub /\W/, "_"

    @graph.add_node res_node_name, {
      label: topic_name.sub(/-[A-Z0-9]{6,20}$/, "").gsub("-", "\n"),
      shape: "rect",
      fontcolor: "red",
    }

    if stmt["Action"].include? "sns:Publish"
      @graph.add_edge node_name, res_node_name, {
      }
    end
  end

  if res.kind_of? String and res.match /^arn:aws:sdb:/
    domain_name = res.split('/').last
    res_node_name = res.gsub /\W/, "_"

    @graph.add_node res_node_name, {
      label: domain_name.sub(/-[A-Z0-9]{6,20}$/, "").gsub("-", "\n"),
      shape: "rect",
      fontcolor: "purple",
    }

    @graph.add_edge node_name, res_node_name, {
    }
  end

  if res.kind_of? String and res.match /^arn:aws:dynamodb:/
    table_name = res.split('/').last
    res_node_name = res.gsub /\W/, "_"

    @graph.add_node res_node_name, {
      label: table_name.sub(/-[A-Z0-9]{6,20}$/, "").gsub("-", "\n"),
      shape: "rect",
      fontcolor: "brown",
    }

    @graph.add_edge node_name, res_node_name, {
    }
  end
end

def process_actor(actor)
  statements = actor.policy_statements

  statements.select {|stmt| stmt["Effect"] == "Allow"}.each do |stmt|
    resources = stmt["Resource"] || []
    resources = [ resources ] unless resources.kind_of? Array
    resources.each do |res|
      process_policy_statement_resource actor, stmt, res
    end
  end
end

################################################################################

@graph = AwsDot::Graph.new

AwsDot::StackCollection.new.each do |stack|
  puts "// Processing #{stack.name}"

  # FIXME BBC-specific
  if stack.guess_env == "live"
    # FIXME BBC-specific
    if stack.name.match /modav|mami|sky|housekeep/i
      process_stack stack
    end
  end
end

AwsDot::SNSQuery.subscriptions.each do |sub|
  next unless sub["Protocol"] == "sqs"

  # FIXME BBC-specific
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

  @graph.add_edge topic_node_name, queue_node_name, {
  }
end

@graph.render
