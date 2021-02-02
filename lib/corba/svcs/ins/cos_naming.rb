#--------------------------------------------------------------------
# cos_naming.rb - Implementation of CosNaming servants
#                 for full featured naming service
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'corba/naming_service'
if defined?(JRUBY_VERSION) or R2CORBA::TAO::RUBY_THREAD_SUPPORT
  require 'monitor'
end

module CosNaming
  # add some useful methods to CosNaming::NameComponent
  class NameComponent
    # create key value for registering in context map
    def to_key
      "#{self.r_id}|#{self.kind}"
    end
    # convert NameComponent to stringified format according to spec
    def to_string
      s = ''
      s = self.r_id.gsub(/([\/\.\\])/,'\\\1') unless self.r_id.to_s.empty?
      s << '.' if s.empty? or !self.kind.to_s.empty?
      s << self.kind.gsub(/([\/\.\\])/,'\\\1') unless self.kind.to_s.empty?
      s
    end
    # convert stringified name back to NameComponent
    def self.from_string(snc)
      raise CosNaming::NamingContext::InvalidName.new if snc.empty?
      esc_ = false
      id_ = ''
      off_ = 0
      snc.size.times do |i|
        case snc[i, 1]
        when '\\'
          esc_ = !esc_
        when '.'
          unless esc_
            raise CosNaming::NamingContext::InvalidName.new if off_ > 0
            id_ = snc[0, i].gsub(/\\(\.|\\)/, '\1')
            off_ = i + 1
          end
          esc_ = false
        else
          esc_ = false
        end
      end
      kind_ = snc[off_, snc.size].gsub(/\\(\.|\\)/, '\1')
      self.new(id_, kind_)
    end
  end
end

module R2CORBA
  module INS

    ##
    # Binding iterator servant class
    #
    class BindingIterator < POA::CosNaming::BindingIterator
      def initialize(reglist, iterator_id)
        @rl = reglist
        @id = iterator_id
      end

      attr_accessor :oid

      def next_one
        reg = @rl.shift
        [!reg.nil?, reg ? CosNaming::Binding.new(reg[:name], reg[:type]) : nil]
      end

      def next_n(how_many)
        raise CORBA::BAD_PARAM.new if how_many < 1
        bindings = []
        while how_many > 0 and !@rl.empty?
          reg = @rl.shift
          bindings << CosNaming::Binding.new(reg[:name], reg[:type])
          how_many -= 1
        end
        [!bindings.empty?, bindings]
      end

      def destroy
        poa = self._default_POA
        poa.deactivate_object(self.oid)
        @rl.clear
        INS::NamingContext.clear_iterator(@id)
      end
    end

    ##
    # Naming context servant class
    #
    class NamingContext < POA::CosNaming::NamingContextExt

      # Map type to store bindings.
      # Use synchronized version for multithreading capable implementations.
      #
      if defined?(JRUBY_VERSION) or R2CORBA::TAO::RUBY_THREAD_SUPPORT
        MAP_TYPE = Class.new(Monitor) do
          def initialize
            super
            @map_ = {}
          end
          def size()
            rc = 0
            synchronize do
              rc = @map_.size
            end
            return rc
          end
          def has_key?(key)
            rc = false
            synchronize do
              rc = @map_.has_key?(key)
            end
            return rc
          end
          def [](key)
            rc = nil
            synchronize do
              rc = @map_[key]
            end
            return rc
          end
          def []=(key, value)
            synchronize do
              @map_[key] = value
            end
            value
          end
          def delete(key)
            rc = nil
            synchronize do
              rc = @map_.delete(key)
            end
            return rc
          end
          def values
            rc = nil
            synchronize do
              rc = @map_.values
            end
            return rc
          end
          def each(&block)
            synchronize do
              @map_.each &block
            end
          end
        end
      else
        MAP_TYPE = Class.new(::Hash) do
          def synchronize(&block)
            yield
          end
        end
      end

      @@iterators = MAP_TYPE.new
      @@iterator_max = 100

      def self.set_iterator_max(max)
        @@iterator_max = max.to_i
      end

      def self.clear_iterator(id)
        @@iterators.delete(id)
      end

      def self.alloc_iterator(reglist)
        @@iterators.synchronize do
          unless @@iterators.size < @@iterator_max
            oldest_id, oldest_it = @iterators.min
            oldest_it.destroy
          end
          itid = Time.now
          return (@@iterators[itid] = INS::BindingIterator.new(reglist, itid))
        end
      end

      def initialize(orb)
        @orb = orb
        @map = MAP_TYPE.new
      end

      attr_accessor :oid

      # CosNaming::NamingContext methods
      #
      def bind(n, obj)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        if n.size > 1
          nc = find_context(n)
          nc.bind(n, obj)
        else
          register_object(n.first, n, CosNaming::Nobject, obj)
        end
      end

      def rebind(n, obj)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        if n.size > 1
          nc = find_context(n)
          nc.rebind(n, obj)
        else
          reregister_object(n.first, n, CosNaming::Nobject, obj)
        end
      end

      def bind_context(n, nc_new)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        if n.size > 1
          nc = find_context(n)
          nc.bind_context(n, nc_new)
        else
          register_object(n.first, n, CosNaming::Ncontext, nc_new)
        end
      end

      def rebind_context(n, nc_new)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        if n.size > 1
          nc = find_context(n)
          nc.rebind_context(n, nc_new)
        else
          reregister_object(n.first, n, CosNaming::Ncontext, nc_new)
        end
      end

      def resolve(n)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        find_object(n)
      end

      def unbind(n)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        if n.size > 1
          nc = find_context(n)
          nc.unbind(n)
        else
          @map.synchronize do
            raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Missing_node,
                                                         n) if !@map.has_key?(n.first.r_id)
            @map.delete(n.last.r_id)
          end
        end
      end

      def new_context()
        poa = self._default_POA
        naming_srv = NamingContext.new(@orb)
        naming_srv.oid = poa.activate_object(naming_srv)
        ::CosNaming::NamingContextExt::_narrow(poa.id_to_reference(naming_srv.oid))
      end

      def bind_new_context(n)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        nc = self.new_context()
        self.bind_context(n, nc)
        nc
      end

      def destroy()
        raise CosNaming::NamingContext::NotEmpty.new if @map.size > 0
        return if self.oid.nil? ## no oid for root context
        poa = self._default_POA
        poa.deactivate_object(self.oid)
        @orb = nil
      end

      def list(how_many)
        reglist = @map.values
        bindings = []
        while how_many > 0 and !reglist.empty?
          reg = reglist.shift
          bindings << CosNaming::Binding.new(reg[:name], reg[:type])
          how_many -= 1
        end
        bi_obj = nil
        if !reglist.empty?
          bi = INS::NamingContext.alloc_iterator(reglist)
          poa = self._default_POA
          bi.oid = poa.activate_object(bi)
          bi_obj = poa.id_to_reference(bi.oid)
        end
        [bindings, CosNaming::BindingIterator._narrow(bi_obj)]
      end

      # CosNaming::NamingContextExt methods
      #
      def to_string(n)
        raise CosNaming::NamingContext::InvalidName.new if n.size < 1
        n.collect { |nc| nc.to_string }.join('/')
      end

      def to_name(sn)
        raise CosNaming::NamingContext::InvalidName.new if sn.to_s.empty?
        snc_arr = []
        off_ = 0
        esc_ = false
        sn.size.times do |i|
          case sn[i,1]
          when '\\'
            esc_ = !esc_
          when '/'
            unless esc_
              snc_arr << sn[off_, i - off_]
              off_ = i + 1
            end
            esc_ = false
          else
            esc_ = false
          end
        end
        snc_arr << sn[off_, sn.size]
        [snc_arr.collect { |snc| CosNaming::NameComponent.from_string(snc) }]
      end

      def to_url(addr, sn)
        raise CosNaming::NamingContext::InvalidName.new if addr.to_s.empty? or sn.to_s.empty?
        url = 'corbaname:' + addr + '#'
        sn.scan(/./) do |ch|
          if /[a-zA-Z0-9;\/:\?@=+\$,\-_\.!~*\'\(\)]/ =~ ch
            url << ch
          else
            url << '%' << ch.unpack('H2').first
          end
        end
        url
      end

      def resolve_str(sn)
        self.resolve(self.to_name(sn).first)
      end

      # Helper methods
      #
      protected

      # register the object reference for a certain NameComponent id
      # no reregistering or duplicates allowed
      #
      def register_object(name, full_name, type, obj)
        key_ = name.to_key
        @map.synchronize do
          raise CosNaming::NamingContext::AlreadyBound.new if @map.has_key?(key_)
          @map[key_] = {
            :name => full_name,
            :type => type,
            :object => obj
          }
        end
      end

      # reregister the object reference for a certain NameComponent id
      #
      def reregister_object(name, full_name, type, obj)
        key_ = name.to_key
        @map.synchronize do
          if @map.has_key?(key_) and @map[key_][:type] != type
            why = (type == CosNaming::Nobject ? CosNaming::NamingContext::Not_object : CosNaming::NamingContext::Not_context)
            raise CosNaming::NamingContext::NotFound.new(why, [])
          end
          @map[key_] = {
            :name => full_name,
            :type => type,
            :object => obj
          }
        end
      end

      # walk all segments of the given CosNaming::Name to find the object
      # bound by this full name
      # NOTE that #find_context is used when the Name contains > 1 level
      # which will automatically shift the segments of Name 1 level while
      # resolving the context levels
      #
      def find_object(n)
        if n.size > 1
          nc = find_context(n)
          nc.resolve(n)
        else
          key_ = n.first.to_key
          @map.synchronize do
            raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Missing_node,
                                                         n) if !@map.has_key?(key_)
            @map[key_][:object]
          end
        end
      end

      # check if there exists a naming context in the current context
      # with the id from the first segment of the given CosNaming::Name
      # return the object reference to the naming context if found
      # NOTE that #shift is used to get AND remove the first Name segment
      # if the naming context is found so that after this call the
      # first segment of the Name is shifted one level
      #
      def find_context(n)
        key_ = n.first.to_key
        @map.synchronize do
          raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Missing_node,
                                                       n) if !@map.has_key?(key_)
          raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Not_context,
                                                       n) if @map[key_][:type] != CosNaming::Ncontext
          n.shift
          @map[key_][:object]
        end
      end

    end #of NamingContext servant

  end
end
