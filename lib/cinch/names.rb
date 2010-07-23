module Cinch
  module Names
    attr_reader :channel_names
    
    def track_names
      @channel_names = {}
      
      on(:join) do |m|
        channel_names[m.channel] ||= []
        channel_names[m.channel].push m.nick
      end
    end
  end
end

class Cinch::Base
  include Cinch::Names
end
