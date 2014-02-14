module StompParser
  class Frame
    HEADER_TRANSLATIONS = {
      '\\r' => "\r",
      '\\n' => "\n",
      '\\c' => ":",
      '\\\\' => '\\',
    }.freeze
    HEADER_TRANSLATIONS_KEYS = Regexp.union(HEADER_TRANSLATIONS.keys).freeze
    HEADER_REVERSE_TRANSLATIONS = HEADER_TRANSLATIONS.invert
    HEADER_REVERSE_TRANSLATIONS_KEYS = Regexp.union(HEADER_REVERSE_TRANSLATIONS.keys).freeze
    SEMICOLON = ";".freeze
    CHARSET_OFFSET = (8..-1).freeze
    ENCODINGS = Encoding.list.each_with_object({}) do |encoding, map|
      encoding.names.each { |name| map[name] = encoding }
      map[encoding.name] = encoding
    end
    EMPTY = "".force_encoding("UTF-8").freeze

    # @return [String]
    attr_reader :command

    # @return [Hash<String, String>]
    attr_reader :headers

    # @return [String]
    attr_reader :body

    # Construct a frame from a command, optional headers, and a body.
    #
    # @param [#to_str] command
    # @param [Hash<String, String>] headers
    # @param [#to_str] body
    def initialize(command = nil, headers_or_body = nil, body = nil)
      if headers_or_body.is_a?(Hash)
        headers = headers_or_body
      else
        body = headers_or_body
      end

      @command = command || EMPTY
      @headers = headers || {}
      @body = body || EMPTY
    end

    # Content length of this frame, according to headers.
    #
    # @raise [ArgumentError] if content-length is not a valid integer
    # @return [Integer, nil]
    def content_length
      if headers.has_key?("content-length")
        begin
          Integer(headers["content-length"])
        rescue ArgumentError
          raise Error, "invalid content length #{headers["content-length"].inspect}"
        end
      end
    end

    def content_type
      headers["content-type"]
    end

    # Determine content encoding by reviewing message headers.
    #
    # @raise [InvalidEncodingError] if encoding does not exist in Ruby
    # @return [Encoding]
    def content_encoding
      if content_type
        mime_type, charset = content_type.split(SEMICOLON, 2)
        charset = charset[CHARSET_OFFSET] if charset
        charset ||= EMPTY

        if charset.empty? and mime_type.start_with?("text/")
          Encoding::UTF_8
        elsif charset.empty?
          Encoding::BINARY
        else
          ENCODINGS[charset] or raise StompParser::InvalidEncodingError, "invalid encoding #{charset.inspect}"
        end
      else
        Encoding::BINARY
      end
    end

    # Change the command of this frame.
    #
    # @param [String] command
    def write_command(command)
      @command = command
    end

    # Write a single header to this frame.
    #
    # @param [String] key
    # @param [String] value
    def write_header(key, value)
      # @see http://stomp.github.io/stomp-specification-1.2.html#Repeated_Header_Entries
      key = translate_header(key)
      @headers[key] = translate_header(value) unless @headers.has_key?(key)
    end

    # Write the body to this frame.
    #
    # @param [String] body
    def write_body(body)
      @body = body.force_encoding(content_encoding)
    end

    # @return [String] a string-representation of this frame.
    def to_str
      frame = "".force_encoding("UTF-8")
      frame << command << "\n"

      outgoing_headers = headers.dup
      outgoing_headers["content-length"] = body.bytesize
      outgoing_headers.each do |key, value|
        frame << serialize_header(key) << ":" << serialize_header(value) << "\n"
      end
      frame << "\n"

      frame << body << "\x00"
      frame
    end
    alias_method :to_s, :to_str

    def [](key)
      @headers[key]
    end

    def destination
      self["destination"]
    end

    private

    # @see http://stomp.github.io/stomp-specification-1.2.html#Value_Encoding
    def translate_header(value)
      value.gsub(HEADER_TRANSLATIONS_KEYS, HEADER_TRANSLATIONS).force_encoding(Encoding::UTF_8) unless value.empty?
    end

    # inverse of #translate_header
    def serialize_header(value)
      value.to_s.gsub(HEADER_REVERSE_TRANSLATIONS_KEYS, HEADER_REVERSE_TRANSLATIONS)
    end
  end
end