#--------------------------------------------------------------------
# config.rb - IDL language mapping configuration for Ruby
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module IDL

  class StrOStream
    def initialize()
      @str = ''
    end
    def clear
      @str = ''
    end
    def to_s
      @str
    end
    def <<(s)
      @str << s
    end
  end # class StrOStream

  class RIDL
    private
    def RIDL.merge_params(params)
      opts = IDL::OPTIONS.dup
      params.each do |k, v|
        case opts[k]
        when Array
          opts[k] = opts[k] + (Array === v ? v : [v])
        when Hash
          opts[k] = opts[k].merge(v) if Hash === v
        else
          opts[k] = v
        end
      end
      opts
    end
    def RIDL.parse0(src, params)
      params = merge_params(params)
      IDL.verbose_level = params[:verbose]
      parser = ::IDL::Parser.new(params)
      parser.parse(src)
      s = ::IDL::StrOStream.new
      s.clear
      IDL::Ruby.process_input(parser, params, s)
      s
    end
    def RIDL.parse(src, params)
      s = parse0(src, params)
      s.to_s
    end
    public
    def RIDL.eval(src, params = {})
      params[:idl_eval] = true
      params[:expand_includes] = true
      params[:client_stubs] = true if params[:client_stubs].nil?
      params[:stubs_only] ||= false
      s = parse0(src, params)
      Kernel.eval(s.to_s, ::TOPLEVEL_BINDING)
      s = nil
    end
    def RIDL.fparse(fname, params = {})
      params[:client_stubs] = true if params[:client_stubs].nil?
      params[:stubs_only] ||= false
      f = File.open(fname, 'r')
      self.parse(f, params)
    ensure
      f.close
    end
    def RIDL.feval(fname, params = {})
      File.open(fname, 'r') { |io| self.eval(io, params) }
    end
  end # module RIDL

  module Ruby
    COPYRIGHT = "Copyright (c) 2007-#{Time.now.year} Remedy IT Expertise BV, The Netherlands".freeze
    TITLE = 'RIDL Ruby backend'.freeze
    VERSION = {
      :major => 2,
      :minor => 0,
      :release => 1
    }

    ## Configure Ruby backend
    #
    Backend.configure('ruby', File.dirname(__FILE__), TITLE, COPYRIGHT, VERSION) do |becfg|

      # setup backend option handling
      #
      becfg.on_setup do |optlist, ridl_params|
        # defaults
        ridl_params[:stub_pfx] = 'C'
        ridl_params[:srv_pfx] = 'S'
        ridl_params[:stubs_only] = false
        ridl_params[:client_stubs] = true
        ridl_params[:expand_includes] = false
        ridl_params[:libinit] = true
        ridl_params[:class_interfaces] = []

        # ruby specific option switches

        unless ridl_params[:preprocess]   # same switch defined for IDL preprocessing mode
          optlist.for_switch '--output=FILE', :type => String,
              :description => ['Specifies filename to generate output in.',
                               'Default: File.basename(idlfile, \'.idl\')+<postfix>+<ext>'] do |swcfg|
            swcfg.on_exec do |arg, params|
              params[:output] = arg
            end

          end
        end

        optlist.for_switch '-o PATH', :type => String,
            :description => ['Specifies output directory.',
                             'Default: ./'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:outputdir] = arg
          end
        end
        optlist.for_switch '--stubs-only',
            :description => ['Only generate client stubs, no servant code.',
                             'Default: off'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:client_stubs] = true
            params[:stubs_only] = true
          end
        end
        optlist.for_switch '--no-stubs',
            :description => ['Do not generate client stubs, only servant code.',
                             'Default: off'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:client_stubs] = false
            params[:stubs_only] = false
          end
        end
        optlist.for_switch '--stub-pfx=POSTFIX', :type => String,
            :description => ['Specifies postfix for generated client stub source filename.',
                             'Filenames are formed like: <idl basename><postfix>.<language extension>',
                             "Default: #{ridl_params[:stub_pfx]}"] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:stub_pfx] = arg
          end
        end
        optlist.for_switch '--skel-pfx=POSTFIX', :type => String,
            :description => ['Specifies postfix for generated servant skeleton source filename.',
                             'Filenames are formed like: <idl basename><postfix>.<language extension>',
                             "Default: #{ridl_params[:srv_pfx]}"] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:srv_pfx] = arg
          end
        end

        optlist.for_switch '--skel-directory=PATH', :type => String,
            :description => ['Specifies output directory for servant files.',
                             'Default: outputdir or ./'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:skel_outputdir] = arg
          end
        end
        optlist.for_switch '--expand-includes',
            :description => ['Generate code for included IDL inline.',
                             'Default: off'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:expand_includes] = true
          end
        end
        optlist.for_switch '--no-libinit',
            :description => ['Do not generate library initialization code as preamble.',
                             'Default: on'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:libinit] = false
          end
        end
        optlist.for_switch '--interface-as-class=INTF', :type => String,
            :description => ['Generate a Ruby class for interface INTF instead of a module in client stubs.',
                             'Default: module'] do |swcfg|
          swcfg.on_exec do |arg, params|
            params[:class_interfaces] << arg
          end
        end
      end

      # process input / generate code
      # arguments:
      #   in parser - parser object with full AST from parsed source
      #   in options - initialized option hash
      #
      becfg.on_process_input do |parser, options|
        IDL::Ruby.process_input(parser, options)
      end # becfg.on_process_input

    end # Backend.configure

    def self.process_input(parser, options, outstream = nil)
      # has a user defined output filename been set
      fixed_output = !options[:output].nil?

      # determine output file path for client stub code
      unless fixed_output || options[:idlfile].nil?
        options[:output] = options[:outputdir] + '/' + File.basename(options[:idlfile], '.idl') + options[:stub_pfx] + '.rb'
      end
      # generate client stubs if requested
      if options[:client_stubs]
        # open output file
        co = outstream || (if options[:output].nil?
           GenFile.new(nil, :output_file => $stdout)
          else
            GenFile.new(options[:output])
          end)
        begin
          # process StubWriter
          parser.visit_nodes(::IDL::RubyStubWriter.new(co, options))
        rescue => ex
          IDL.log(0, ex)
          IDL.log(0, ex.backtrace.join("\n")) unless ex.is_a? IDL::ParseError
          exit 1
        end
      end

      # determin output file path for servant code and open file
      unless options[:stubs_only]
        so = outstream || (unless fixed_output || options[:idlfile].nil?
            options[:srv_output] = if fixed_output
                options[:output]
              else
                options[:outputdir] + '/' + File.basename(options[:idlfile], '.idl') + options[:srv_pfx] + '.rb'
              end
            if fixed_output && options[:client_stubs]
              co
            else
              GenFile.new(options[:srv_output])
            end
          else
            GenFile.new(nil, :output_file => $stdout)
          end)
        begin
          # process ServantWriter
          parser.visit_nodes(::IDL::RubyServantWriter.new(so, options))
        rescue => ex
          IDL.log(0, ex)
          IDL.log(0, ex.backtrace.join("\n")) unless ex.is_a? IDL::ParseError
          exit 1
        end
      end
    end

    module LeafMixin

      RESERVED_RUBY_CONST = %w(Array Bignum Binding Class Continuation Dir Exception FalseClass File
          Fixnum Float Hash Integer IO MatchData Method Module NilClass Numeric Object Proc Process
          Range Regexp String Struct Symbol Thread ThreadGroup Time TrueClass UnboundMethod Comparable
          Enumerable Errno FileTest GC Kernel Marshal Math ObjectSpace Signal)

      RESERVED_RUBY_MEMBER = %w(untaint id instance_variable_get inspect taint public_methods
          __send__ to_a display instance_eval extend clone protected_methods hash freeze type
          instance_variable_set methods instance_variables to_s method dup private_methods object_id
          send __id__ singleton_methods proc readline global_variables singleton_method_removed callcc
          syscall fail untrace_var load srand puts catch chomp initialize_copy format scan print abort
          fork gsub trap test select initialize method_missing lambda readlines local_variables
          singleton_method_undefined system open caller eval set_trace_func require rand
          singleton_method_added throw gets binding raise warn getc exec trace_var irb_binding at_exit
          split putc loop chop sprintf p remove_instance_variable exit printf sleep sub autoload)

      def ruby_lm_name
        unless @lm_name
          ret = @name.checked_name.dup
          case self
          when IDL::AST::Port,
              IDL::AST::StateMember,
              IDL::AST::Initializer,
              IDL::AST::Parameter,
              IDL::AST::Operation,
              IDL::AST::Attribute,
              IDL::AST::Member,
              IDL::AST::UnionMember
            # member names
            ret = ret[0, 1].downcase + ret[1, ret.size].to_s
            ret = 'r_' + ret if IDL::Ruby::LeafMixin::RESERVED_RUBY_MEMBER.include?(ret)
          else
            # class/module names
            ret = ret[0, 1].upcase + ret[1, ret.size].to_s
            is_scoped = @enclosure && !@enclosure.scopes.empty?
            ret = 'R_' + ret if !is_scoped && IDL::Ruby::LeafMixin::RESERVED_RUBY_CONST.include?(ret)
          end
          @lm_name = ret
        end
        @lm_name
      end

      def rubyname
        lm_name
      end

      def scoped_rubyname
        scoped_lm_name
      end
    end # module LeafMixin

    IDL::AST::Leaf.class_eval do
      include LeafMixin

      alias :base_lm_name :lm_name
      alias :lm_name :ruby_lm_name
    end

    module ScannerMixin

      RUBYKW = %w(__FILE__ and def end in or self unless __LINE__ begin defined? ensure module redo
          super until BEGIN break do false next rescue then when END case else for nil retry true while
          alias class elsif if not return undef yield).collect! { |w| w.to_sym }

      def chk_identifier(ident)
        # prefix Ruby keywords with 'r_'
        RUBYKW.include?(ident.to_sym) ? 'r_' + ident : ident
      end

    end # module ScannerMixin

    IDL::Scanner.class_eval do
      include ScannerMixin
    end

  end # module Ruby

end # module IDL
