module Cinch
  # @since 2.0.0
  class Target
    include Comparable

    # @return [String]
    attr_reader :name
    # @return [Bot]
    attr_reader :bot
    def initialize(name, bot)
      @name = name
      @bot  = bot
    end

    # Sends a NOTICE to the target.
    #
    # @param [#to_s] text the message to send
    # @return [void]
    # @see #safe_notice
    def notice(text)
      msg(text, true)
    end

    # Sends a PRIVMSG to the target.
    #
    # @param [#to_s] text the message to send
    # @param [Boolean] notice Use NOTICE instead of PRIVMSG?
    # @return [void]
    # @see #safe_msg
    # @note The aliases `msg` and `privmsg` are deprecated and will be
    #   removed in a future version.
    def send(text, notice = false)
      # TODO deprecate `notice` argument, put splitting into own
      # method
      text = text.to_s
      split_start = @bot.config.message_split_start || ""
      split_end   = @bot.config.message_split_end   || ""
      command = notice ? "NOTICE" : "PRIVMSG"

      text.split(/\r\n|\r|\n/).each do |line|
        maxlength = 510 - (":" + " #{command} " + " :").size
        maxlength = maxlength - @bot.mask.to_s.length - @name.to_s.length
        maxlength_without_end = maxlength - split_end.bytesize

        if line.bytesize > maxlength
          splitted = []

          while line.bytesize > maxlength_without_end
            pos = line.rindex(/\s/, maxlength_without_end)
            r = pos || maxlength_without_end
            splitted << line.slice!(0, r) + split_end.tr(" ", "\u00A0")
            line = split_start.tr(" ", "\u00A0") + line.lstrip
          end

          splitted << line
          splitted[0, (@bot.config.max_messages || splitted.size)].each do |string|
            string.tr!("\u00A0", " ") # clean string from any non-breaking spaces
            @bot.irc.send("#{command} #@name :#{string}")
          end
        else
          @bot.irc.send("#{command} #@name :#{line}")
        end
      end
    end
    alias_method :msg, :send # deprecated
    alias_method :privmsg, :send # deprecated
    undef_method(:msg) # yardoc hack
    undef_method(:privmsg) # yardoc hack

    # @deprecated
    def msg(*args)
      Cinch::Utilities::Deprecation.print_deprecation("2.2.0", "Target#msg", "Target#send")
      send(*args)
    end

    # @deprecated
    def privmsg(*args)
      Cinch::Utilities::Deprecation.print_deprecation("2.2.0", "Target#privmsg", "Target#send")
      send(*args)
    end

    # Like {#send}, but remove any non-printable characters from
    # `text`. The purpose of this method is to send text of untrusted
    # sources, like other users or feeds.
    #
    # Note: this will **break** any mIRC color codes embedded in the
    # string. For more fine-grained control, use
    # {Helpers#Sanitize} and
    # {Formatting.unformat} directly.
    #
    # @return (see #send)
    # @param (see #send)
    # @see #send
    def safe_send(text, notice = false)
      send(Cinch::Helpers.sanitize(text), notice)
    end
    alias_method :safe_msg, :safe_send # deprecated
    alias_method :safe_privmsg, :safe_msg # deprecated
    undef_method(:safe_msg) # yardoc hack
    undef_method(:safe_privmsg) # yardoc hack

    # @deprecated
    def safe_msg(*args)
      Cinch::Utilities::Deprecation.print_deprecation("2.2.0", "Target#safe_msg", "Target#safe_send")
      send(*args)
    end

    # @deprecated
    def safe_privmsg(*args)
      Cinch::Utilities::Deprecation.print_deprecation("2.2.0", "Target#safe_privmsg", "Target#safe_send")
      send(*args)
    end


    # Like {#safe_msg} but for notices.
    #
    # @return (see #safe_msg)
    # @param (see #safe_msg)
    # @see #safe_notice
    # @see #notice
    def safe_notice(text)
      safe_msg(text, true)
    end

    # Invoke an action (/me) in/to the target.
    #
    # @param [#to_s] text the message to send
    # @return [void]
    # @see #safe_action
    def action(text)
      @bot.irc.send("PRIVMSG #@name :\001ACTION #{text}\001")
    end

    # Like {#action}, but remove any non-printable characters from
    # `text`. The purpose of this method is to send text from
    # untrusted sources, like other users or feeds.
    #
    # Note: this will **break** any mIRC color codes embedded in the
    # string. For more fine-grained control, use
    # {Helpers#Sanitize} and
    # {Formatting.unformat} directly.
    #
    # @param (see #action)
    # @return (see #action)
    # @see #action
    def safe_action(text)
      action(Cinch::Helpers.Sanitize(text))
    end

    # Send a CTCP to the target.
    #
    # @param [#to_s] message the ctcp message
    # @return [void]
    def ctcp(message)
      send "\001#{message}\001"
    end

    def concretize
      if @bot.isupport["CHANTYPES"].include?(@name[0])
        @bot.channel_list.find_ensured(@name)
      else
        @bot.user_list.find_ensured(@name)
      end
    end

    # @return [Boolean]
    def eql?(other)
      self == other
    end

    # @param [Target, String] other
    # @return [-1, 0, 1, nil]
    def <=>(other)
      casemapping = @bot.irc.isupport["CASEMAPPING"]
      left = @name.irc_downcase(casemapping)

      if other.is_a?(Target)
        left <=> other.name.irc_downcase(casemapping)
      elsif other.is_a?(String)
        left <=> other.irc_downcase(casemapping)
      else
        nil
      end
    end
  end
end
