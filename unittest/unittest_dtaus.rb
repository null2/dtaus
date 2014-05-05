#encoding: cp850
require 'test/unit'
require 'more_unit_test/assert_equal_filecontent'
require 'more_unit_test/assert_stdout'
#~ require 'flexmock/test_unit'
    #~ flexmock(Date).should_receive(:today).returns(Date.new(2007,9,14))

if $0 == __FILE__
  $:.unshift('../lib')
else
  #Change the directory. Relevant, if called from rakefile_rake4latex.rb
  Dir.chdir(File.dirname(__FILE__))
end
require 'DTAUS'
$expected = 'expected'
$testdate = Date.new(2007, 9, 14)

class Test_Konto < Test::Unit::TestCase
  def test_konto_init()
    
    #Check Konto
    assert_raise(ArgumentError){ DTAUS::Konto.new() }
    assert_raise(ArgumentError){ DTAUS::Konto.new(123 ) }
    assert_raise(ArgumentError){ DTAUS::Konto.new(123, 23) }
    
    assert_nothing_raised{ DTAUS::Konto.new(123, 23, 'mein Name' ) }
    assert_nothing_raised{ DTAUS::Konto.new('123', '23', 'mein Name' ) }
    
    #Kontonr/BLZ muss als Zahl interpretierbar sein
    assert_raise(ArgumentError){ DTAUS::Konto.new(123, 'xx', 'mein Name') }
    assert_raise(ArgumentError){ DTAUS::Konto.new('xx', 12, 'mein Name') }
  end #
end #Test_Buchung < Test::Unit::TestCase

class Test_Buchung < Test::Unit::TestCase
  KONTO = DTAUS::Konto.new(123, 23, 'mein Name')
  
  def test_buchung_init()
    
    assert_raise(ArgumentError){ DTAUS::Buchung.new() }
    #Check Konto
    assert_raise(ArgumentError){ DTAUS::Buchung.new(123) }
    assert_raise(ArgumentError){ DTAUS::Buchung.new(123, 23.5 ) }
    
    assert_nothing_raised(){ DTAUS::Buchung.new(KONTO, 23.5, 'text' ) }
    
  end #test_buchung()

  def test_buchung_betrag()
    
    b = nil #global machen
    
    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, 23.5, 'text' ) }
    assert_equal(2350, b.betrag)

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, "24.5", 'text' ) }
    assert_equal(2450, b.betrag)

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, "25,5", 'text' ) }
    assert_equal(2550, b.betrag)

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, "24.50", 'text' ) }
    assert_equal(2450, b.betrag)

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, "25,50", 'text' ) }
    assert_equal(2550, b.betrag)

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, 23, 'text' ) }
    assert_equal(2300, b.betrag)

    assert_raise(ArgumentError){ b = DTAUS::Buchung.new(KONTO, :xx, 'text' ) }
    assert_raise(ArgumentError){ b = DTAUS::Buchung.new(KONTO, 'xx', 'text' ) }

  end #test_buchung()

  def test_betrag_float_error()
    b = nil #global machen

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, '20.4', 'text' ) }
    assert_equal(2040, b.betrag)

    assert_nothing_raised(){ b = DTAUS::Buchung.new(KONTO, 20.4, 'text' ) }
    assert_equal(2039, b.betrag, 'Hier sollte 2040 kommen')
    
  end #test_betrag_float_error()
  
end #Test_Buchung < Test::Unit::TestCase


class Test_dtaus_rb < Test::Unit::TestCase
  #~ def test_initialize()
    #~ assert_raise(NoMethodError){ Basefile.new() } #private method
    #~ assert_raise(ArgumentError){ Basefile.set() }
    
    #~ assert_equal(nil, Basefile['test_basefile.tex'])
    #~ assert_nothing_raised(ArgumentError){ Basefile.set( 'test_basefile.tex') }
    #~ #Test different variations with different extensions.
    #~ assert_equal(Basefile['test_basefile.tex'], Basefile.set( 'test_basefile.tex'))
    #~ assert_equal(Basefile['test_basefile.tex'], Basefile.set( 'test_basefile'))
    #~ assert_equal(Basefile['test_basefile'], Basefile.set( 'test_basefile.tex'))
    #~ assert_equal(Basefile['test_basefile.pdf'], Basefile.set( 'test_basefile.tex'))

    #~ #Undefined key.
    #~ assert_raise(ArgumentError){ Basefile.set( 'test_basefile.tex', :xx => 1) }
    #~ assert_nothing_raised(ArgumentError){ Basefile.set( 'test_basefile.tex', :loglevel => 1) }

  #~ end #test_initialize
  
  def test_missing_datafiles()
    #DOS-Box has codepage 850 (cp850)
    #For ruby 1.9, the test script must start with the same encoding.
    assert_stdout_block( "Keine Dateien übergeben\n" ){ puts `call "../lib/dtaus.rb" -b testdata/test_buchung.txt` }
    assert_stdout_block( "Keine Dateien übergeben\n" ){ puts `call "../lib/dtaus.rb" -k testdata/test_konto.txt` }
    assert_stdout_block( "Keine Dateien übergeben\n" ){ puts `call "../lib/dtaus.rb" ` }
  end
  
  def test_dtaus_rb()
    #Delete old files
    #~ %w{Begleitblatt.txt DTAUS0.TXT}.each{|filename|
      #~ File.delete(filename) if File.exist?(filename)
      #~ assert_equal(false, File.exist?(filename))
    #~ }

    #~ assert_equal_stdout( "Keine Dateien übergeben", `call "../lib/dtaus.rb"  -b testdata/test_buchung.txt`)

    stdout = `call "../lib/dtaus.rb" --no-cr  -k testdata/test_konto.txt -b testdata/test_buchung.txt`
    stdout.gsub!(Date.today.strftime("%d.%m.%Y"), $testdate.strftime("%d.%m.%Y"))

    assert_equal_filecontent( "#{$expected}/dtaus_stdout.txt", stdout)

    #~ system( '../lib/dtaus.rb -k testdata/test_konto.txt -b testdata/test_buchung.txt')
    
    %w{Begleitblatt.txt DTAUS0.TXT}.each{|filename|
      assert_equal(true, File.exist?(filename))
      
      fcontent = File.read(filename)
      #convert all time stamps
      [ "%d.%m.%Y", "%d%m%y", "%d%m%Y"].each{|datepattern|
        fcontent.gsub!(Date.today.strftime(datepattern), $testdate.strftime(datepattern))
      }
      assert_equal_filecontent( "#{$expected}/#{filename}", fcontent )
          
      File.delete(filename) if File.exist?(filename)
    }
  end
end

