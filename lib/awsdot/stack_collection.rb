module AwsDot

  class StackCollection

    include Enumerable

    # STACKS_DIR should contain one subdir for each stack you want to analyze,
    # where each subdir contains resources.json, template.json and
    # description.json (as produced by the 'aws' command line tool).
    STACKS_DIR = "./stacks"

    def each
      Dir.entries(STACKS_DIR).each do |n|
        unless n.start_with? "."
          yield Stack.new(n, "#{STACKS_DIR}/#{n}")
        end
      end
    end

  end

end
