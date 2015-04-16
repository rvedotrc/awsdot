module AwsDot

  class Graph

    def initialize
      @nodes = {}
      @edges = {}
    end

    def add_node(id, opts)
      @nodes[id] = opts
    end

    def add_edge(from_id, to_id, opts)
      @edges[ [from_id, to_id] ] = opts
    end

    def render
      nodes = @nodes
      edges = @edges

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

    private

    def dot_string(s)
      s.inspect
    end

  end

end
