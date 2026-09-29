require 'optparse'
require 'bigdecimal'
require 'lib/assert.rb'
include TestUtil::Assertions

OPTIONS = {
  use_implement: false,
  orb_debuglevel: 0,
  iorfile: 'file://server.ior'
}

ARGV.options do |opts|
  opts.on('--k IORFILE', 'Set IOR.') { |v| OPTIONS[:iorfile] = v }
  opts.on('--d LVL', 'Set ORBDebugLevel value.') { |v| OPTIONS[:orb_debuglevel] = v }
  opts.on('--use-implement', 'Load IDL through CORBA.implement().') { OPTIONS[:use_implement] = true }
  opts.on('-h', '--help', 'Show this help message.') { puts opts; exit }
  opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba'
  CORBA.implement('Test.idl', OPTIONS)
else
  require 'TestC.rb'
end

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')
begin
  obj = orb.string_to_object(OPTIONS[:iorfile])
  fixed_obj = Test::FixedValues._narrow(obj)

  value = BigDecimal('123.456')
  assert('fixed constant is incorrect', Test::Fixed_Constant == BigDecimal('1.234'))
  assert('fixed round trip failed', fixed_obj.echo_fixed(value) == value)
  assert('fixed Any round trip failed', fixed_obj.echo_any(value) == value)
  odd_precision_value = BigDecimal('12.345')
  assert('odd precision fixed Any round trip failed',
         fixed_obj.echo_any(odd_precision_value) == odd_precision_value)
  small_fraction_value = BigDecimal('1e-8')
  assert('small fraction fixed Any round trip failed',
         fixed_obj.echo_any(small_fraction_value) == small_fraction_value)
  integer_value = BigDecimal('123')
  assert('integer fixed Any round trip failed', fixed_obj.echo_any(integer_value) == integer_value)
  max_precision_value = BigDecimal('123456789012345678901234567890')
  assert('maximum precision fixed Any round trip failed',
         fixed_obj.echo_any(max_precision_value) == max_precision_value)
  max_whole_value = BigDecimal('9999999999999999999999999999999')
  assert('maximum 31-digit whole fixed Any round trip failed',
         fixed_obj.echo_any(max_whole_value) == max_whole_value)
  [BigDecimal('Infinity'), BigDecimal('NaN')].each do |non_finite_value|
    assert_except('non-finite fixed Any value was accepted', CORBA::DATA_CONVERSION) do
      fixed_obj.echo_any(non_finite_value)
    end
  end
  assert_except('fixed Any precision overflow was accepted', CORBA::DATA_CONVERSION) do
    fixed_obj.echo_any(BigDecimal('1234567890123456789012345678901'))
  end
  assert_except('fixed scale overflow was accepted', CORBA::DATA_CONVERSION) do
    fixed_obj.echo_fixed(BigDecimal('1.2345'))
  end
  assert_except('fixed precision overflow was accepted', CORBA::DATA_CONVERSION) do
    fixed_obj.echo_fixed(BigDecimal('12345678.901'))
  end

  values = [BigDecimal('0.001'), BigDecimal('-987.654')]
  returned_values = fixed_obj.echo_sequence(values)
  assert('fixed sequence round trip failed', returned_values == values)

  array = [BigDecimal('1.200'), BigDecimal('-3.400')]
  returned_array = fixed_obj.echo_array(array)
  assert('fixed array round trip failed', returned_array == array)

  fixed_obj.shutdown
ensure
  orb.destroy
end
