require "binary/protocol/version"
require "binary/protocol/extensions"

module Binary
  module Protocol

    BYTES_8  = 1.freeze
    BYTES_16 = 2.freeze
    BYTES_32 = 4.freeze
    BYTES_64 = 8.freeze

    INT8_PACK       = 'c'.freeze  # 8-bit signed (signed char)
    INT16_PACK      = 's'.freeze  # 16-bit signed, native endian (int16_t)
    INT32_PACK      = 'l'.freeze  # 32-bit signed, native endian (int32_t)
    INT64_PACK      = 'q'.freeze  # 64-bit signed, native endian (int64_t)
    INT16BE_PACK    = 's>'.freeze # 16-bit signed, big-endian
    INT32BE_PACK    = 'l>'.freeze # 32-bit signed, big-endian
    INT64BE_PACK    = 'q>'.freeze # 64-bit signed, big-endian
    INT16LE_PACK    = 's<'.freeze # 16-bit signed, little-endian
    INT32LE_PACK    = 'l<'.freeze # 32-bit signed, little-endian
    INT64LE_PACK    = 'q<'.freeze # 64-bit signed, little-endian

    UINT8_PACK      = 'C'.freeze  # 8-bit unsigned (unsigned char)
    UINT16_PACK     = 'S'.freeze  # 16-bit unsigned, native endian (uint16_t)
    UINT32_PACK     = 'L'.freeze  # 32-bit unsigned, native endian (uint32_t)
    UINT64_PACK     = 'Q'.freeze  # 64-bit unsigned, native endian (uint64_t)
    UINT16BE_PACK   = 'n'.freeze  # 16-bit unsigned, network (big-endian) byte order
    UINT32BE_PACK   = 'N'.freeze  # 32-bit unsigned, network (big-endian) byte order
    UINT64BE_PACK   = 'Q>'.freeze # 64-bit unsigned, network (big-endian) byte order
    UINT16LE_PACK   = 'v'.freeze  # 16-bit unsigned, VAX (little-endian) byte order
    UINT32LE_PACK   = 'V'.freeze  # 32-bit unsigned, VAX (little-endian) byte order
    UINT64LE_PACK   = 'Q<'.freeze # 64-bit unsigned, VAX (little-endian) byte order

    SINGLE_PACK     = 'F'.freeze  # 32-bit single-precision, native format
    DOUBLE_PACK     = 'D'.freeze  # 64-bit double-precision, native format
    SINGLEBE_PACK   = 'g'.freeze  # 32-bit sinlge-precision, network (big-endian) byte order
    DOUBLEBE_PACK   = 'G'.freeze  # 64-bit double-precision, network (big-endian) byte order
    SINGLELE_PACK   = 'e'.freeze  # 32-bit sinlge-precision, little-endian byte order
    DOUBLELE_PACK   = 'E'.freeze  # 64-bit double-precision, little-endian byte order

    class << self

      # Extends the including class with +ClassMethods+.
      #
      # @param [Class] subclass the inheriting class
      def included(base)
        super

        base.extend ClassMethods
      end

      private :included
    end

    # Provides a DSL for defining struct-like fields for building
    # binary messages.
    #
    # @example
    #   class Command
    #     include Binary::Protocol
    #
    #     int32 :length
    #   end
    #
    #   Command.fields # => [:length]
    #   command = Command.new
    #   command.length = 12
    #   command.serialize_length("") # => "\f\x00\x00\x00"
    module ClassMethods

      # @return [Array] the methods to run in order for serialiation
      def serialization
        @serialization ||= []
      end

      # @return [Array] the fields defined for this message
      def fields
        @fields ||= []
      end

      %w[
        int8
        int16
        int32
        int64
        int16be
        int32be
        int64be
        int16le
        int32le
        int64le
        uint8
        uint16
        uint32
        uint64
        uint16be
        uint32be
        uint64be
        uint16le
        uint32le
        uint64le
      ].each do |name|
        pack_const = "#{name.upcase}_PACK".intern
        size_const = "BYTES_#{name.match(/(\d+)/)[0]}".intern
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}(name, options = {}, &block)
            __bytes__(#{pack_const.inspect}, #{size_const.inspect}, name, options, &block)
          end
        RUBY
      end

      %w[
        single
        singlebe
        singlele
        double
        doublebe
        doublele
      ].each do |name|
        pack_const = "#{name.upcase}_PACK".intern
        size_const = !!(name =~ /single/) ? "BYTES_32".intern : "BYTES_64".intern
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}(name, options = {}, &block)
            __bytes__(#{pack_const.inspect}, #{size_const.inspect}, name, options, &block)
          end
        RUBY
      end

      # Declare a string field.
      #
      # @example
      #   class Message
      #     include Binary::Protocol
      #     string :collection
      #   end
      #
      # @param [String] name the name of this field
      def string(name, options = {})
        if options.key?(:always)
          __define_always__(name, options[:always])
        else
          if options.key?(:default)
            __define_default__(name, options[:default])
          else
            attr_accessor name
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def deserialize_#{name}(buffer)
              raise NotImplementedError
            end
          RUBY
        end

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def serialize_#{name}(buffer)
            buffer << #{name}
          end
        RUBY

        serialization << :"serialize_#{name}"
        fields << name
      end

      # Declare a null terminated string field.
      #
      # @example
      #   class Message
      #     include Binary::Protocol
      #     stringz :collection
      #   end
      #
      # @param [String] name the name of this field
      def stringz(name, options = {})
        if options.key?(:always)
          __define_always__(name, options[:always])
        else
          if options.key?(:default)
            __define_default__(name, options[:default])
          else
            attr_accessor name
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def deserialize_#{name}(buffer)
              raise NotImplementedError
            end
          RUBY
        end

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def serialize_#{name}(buffer)
            buffer << #{name}
            buffer << 0
          end
        RUBY

        serialization << :"serialize_#{name}"
        fields << name
      end

      # Declares the protocol class as complete, and defines its serialization
      # method from the declared fields.
      def finalize
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def serialize(buffer = "")
            #{serialization.map { |command| "#{command}(buffer)" }.join("\n")}
            buffer
          end
          alias to_s serialize
        RUBY
      end

      def deserialize(buffer = nil, &block)
        if block_given?
          re_define_method(:deserialize, &block)
        else
          message = allocate
          message.deserialize(buffer)
          message
        end
      end

      protected

      def __bytes__(pack_const, size_const, name, options = {}, &block)
        if block_given?
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def before_serialize_#{name}(buffer)
              @#{name}_start = buffer.bytesize
            end
          RUBY

          serialization << :"before_serialize_#{name}"
        end

        if options.key?(:always)
          __define_always__(name, options[:always])
        else
          if options.key?(:default)
            __define_default__(name, options[:default])
          else
            attr_accessor name
          end

          if options[:type] == :array
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def deserialize_#{name}(buffer)
                raise NotImplementedError
              end
            RUBY
          else
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def deserialize_#{name}(buffer)
                self.#{name}, = buffer.read(#{size_const}).unpack(#{pack_const})
              end
            RUBY
          end
        end

        if options[:type] == :array
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def serialize_#{name}(buffer)
              buffer << #{name}.pack(#{pack_const}+"*")
            end
          RUBY
        else
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def serialize_#{name}(buffer)
              buffer << [#{name}].pack(#{pack_const})
            end
          RUBY
        end

        serialization << :"serialize_#{name}"

        if block_given?
          returning = fields << name
          instance_eval(&block)

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def after_serialize_#{name}(buffer)
              self.#{name} = buffer.bytesize - @#{name}_start - #{options[:inclusive] ? 0 : size_const}
              buffer[@#{name}_start, #{size_const}] = serialize_#{name} ""
            end
          RUBY

          serialization << :"after_serialize_#{name}"

          returning
        else
          fields << name
        end
      end

      def __define_always__(name, always)
        if always.respond_to?(:call)
          re_define_method(name, &always)
        else
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              @#{name} ||= #{always.inspect}
            end
          RUBY
        end
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def deserialize_#{name}(buffer)
            # do nothing
          end
        RUBY
      end

      def __define_default__(name, default)
        attr_writer name

        if default.respond_to?(:call)
          dval = :"__#{name}_default_value__"
          ivar = :"@#{name}"
          re_define_method(dval, &default)
          re_define_method(name) do
            if instance_variable_defined?(ivar)
              instance_variable_get(ivar)
            else
              instance_variable_set(ivar, __send__(dval))
            end
          end
        else
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}
              @#{name} ||= #{default.inspect}
            end
          RUBY
        end
      end

      private

      # This ensures that subclasses of the primary protocol classes have
      # identical fields.
      def inherited(subclass)
        super

        subclass.serialization.replace serialization
        subclass.fields.replace fields
      end

    end

    # Default implementation for a message is to do nothing when receiving
    # replies.
    #
    # @example Receive replies.
    #   message.receive_replies(connection)
    #
    # @param [ Connection ] connection The connection.
    #
    # @since 1.0.0
    #
    # @return [ nil ] nil.
    def receive_replies(connection); end

    def deserialize(buffer)
      self.class.fields.each do |field|
        __send__(:"deserialize_#{field}", buffer)
      end
      self
    end

    # Serializes the message and all of its fields to a new buffer or to the
    # provided buffer.
    #
    # @param [String] buffer a buffer to serialize to
    # @return [String] the result of serliazing this message
    def serialize(buffer = "")
      raise NotImplementedError, "This method is generated after calling #finalize on a message class"
    end
    alias to_s serialize

    # @return [String] the nicely formatted version of the message
    def inspect
      fields = self.class.fields.map do |field|
        "@#{field}=" + __send__(field).inspect
      end
      "#<#{self.class.name} " <<
      "#{fields * " "}>"
    end

    def pretty_inspect
      fields = self.class.fields.map do |field|
        "@#{field}=" + __send__(field).inspect
      end
      "#<#{self.class.name}\n" <<
      "  #{fields * "\n  "}>"
    end

  end
end
