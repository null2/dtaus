#encoding: cp1252
#:title:DTAUS-erzeugen zur Abrechnung
#
#=DTAUS-erzeugen zum automatischen Einzug bei Banken.
#
#This program allows the creation of a DTAUS-File.
#This files are used by German banks for money transfers.
#
#The following documentation is in German.
#I expect only German users for this program.
#
#Die Nutzung dieses Programms erfolgt auf eigene Gefahr!
#Ich übernehmen keinerlei Garantie auf Richtigkeit und Funktionstüchtigkeit dieses Programms.
#
#Dieses Programm ist frei - aber auf eigene Gefahr - nutzbar.
#Das Programm wird von einem mir nahestehenden Verein erfolgreich genutzt,
#der Praxistest hat das Programm zumindest bestanden.
#
#Eine Anleitung und aktuelle Version findet sich unter
#		http://ruby.lickert.net/dtaus
#
#Hinweis: Zur Erstellung des Begleitblattes ist LaTeX notwendig.
#Informationen zu TeX und LaTeX findet sich unter http://www.dante.de
#Es besteht alternativ die Möglichkeit ein Begleitblatt im ASCII-Format
#zu erzeugen.

#
# Idee: Bankadresse / Bankort

#~ /* This program is free software. It comes without any warranty, to
 #~ * the extent permitted by applicable law. You can redistribute it
 #~ * and/or modify it under the terms of the Do What The Fuck You Want
 #~ * To Public License, Version 2, as published by Sam Hocevar. See
 #~ * http://sam.zoy.org/wtfpl/COPYING for more details. 
 #~ * Benutzung auf eigene Gefahr
 #~ */

require 'optparse'

#
#Erstelle eine DTAUS-Datei.
#Typ ist 'LK' (Lastschrift Kunde) oder 'GK' (Gutschrift Kunde)
#
#Infos zu DTAUS: http://www.infodrom.org/projects/dtaus/dtaus.php3
#
#Die Methoden müssen in der Reihenfolge:
#- konto	(definieren des eigenen Kontos)
#- buchungen
#- dtaDatei/begleitblatt
#abgearbeitet werden.
#
class DTAUS
  VERSION = '0.2.2'
	#Kontodaten verwalten mit Name des Inhabers und Bank, Bankleitzahl und Kontonummer.
	class Konto
		def initialize( konto, blz, name, bank="", kunnr="" )
			if konto.kind_of?( Integer )
				@konto = konto
			else
				@konto	= konto.gsub(/\s/, '').to_i
			end
			if blz.kind_of?( Integer )
				@blz = blz
			else
				@blz		= blz.gsub(/\s/, '').to_i
			end
			@bank	= bank
			@bankStrasse = @bankPLZ = @bankOrt = nil
			@name	= name
			@kunnr	= kunnr.gsub(/\s/, '').to_i
			raise ArgumentError, "Kontonummer #{konto} ungültig"	if @konto	== 0
			raise ArgumentError, "BLZnummer #{blz} ungültig"		if @blz	== 0
			raise ArgumentError, "Name des Kontoinhabers #{name} ungültig"	if !@name.kind_of?(String)
			raise ArgumentError, "Bankname #{bank} ungültig"	if !@bank.kind_of?(String)
			@dtaname	= DTAUS.convert_text( @name )
			@dtabank	= DTAUS.convert_text( @bank )
			@dtakunnr	= DTAUS.convert_text( @kunnr )
		end
		attr_writer		:bankStrasse, :bankPLZ, :bankOrt
		attr_reader	:bankStrasse, :bankPLZ, :bankOrt
		# dta~ jeweilige Feld in DTAUS-Norm
		attr_reader	:blz, :bank, :dtabank, :name, :dtaname, :kunnr, :dtakunnr
		def nummer; @konto end
	end	#class Konto
	
	class Buchung
		#Eine Buchung ist definiert durch:
		#- Konto (siehe Klasse Konto
		#- Betrag
		#	Der Betrag kann , oder . als Dezimaltrenner enthalten.
		#- optional Buchungstext
		def initialize( konto, betrag, text=nil )
			@konto	= konto
			@text	= text
			raise ArgumentError, "Übergabefehler: Konto" if ! @konto.kind_of?( Konto )
			raise ArgumentError, "Übergabefehler: Text kein String" if ! @text.kind_of?( String )
			@dtatext	= DTAUS.convert_text( @text )
      case betrag
        when /\A(\d+)[\.,](\d\d)\Z/   #e.g. 25.00
          betrag = ( $1.to_i * 100 ) + $2.to_i #€-Cent
        when /\A(\d+)[\.,](\d)\Z/   #e.g. 25.0
          betrag = ( $1.to_i * 100 ) + $2.to_i * 10 #€-Cent
        when /\A(\d+)\Z/              #e.g. 25
          betrag = ( $1.to_i * 100 ) #€-Cent
        when Float, Integer
          betrag = ( betrag * 100 ).to_i	#€-Cent
        else
          raise ArgumentError, "Übergabefehler: Betrag ist kein String/Float #{betrag.inspect}"
			end
      
      
			if betrag == 0
				raise ArgumentError, "Betrag Null"
			elsif betrag > 0
				@betrag	= betrag
				@positiv	= true
			else
				@betrag	= - betrag
				@positiv	= false
			end
		end
    #Betrag in €-Cent
    attr_reader :betrag
		def positiv?; @positiv end
		def konto; @konto end
		def text; @text end
		def dtatext; @dtatext end
	end	#class Buchung
  
=begin rdoc  
Erstelle DTAUS-Objekt.

Zieldatei und Datum der Datei werden definiert
=end
	def initialize( typ, datum = Date.today )
    
		if datum.kind_of?( Date )
			@datum 		= datum
		#~ elif type(datum) == type("sting"):	# Datum im Format yyyy-mm-dd
			#~ dat = datum.split('-')
			#~ @datum = (int(dat[0]), int(dat[1]), int(dat[2]), 0, 0, 0, 0, 0, 0)
			#~ print @datum
		else
			raise "Bitte Datum im Format yyyy-mm-dd übergeben"
		end
		if typ == 'LK'	
			@typ		= 'LK'
			@typText	= 'Sammeleinziehungsauftrag'
		elsif typ == 'GK'
			@typ		= 'GK'
			@typText	= 'Sammel-Überweisung'
		else
			raise "Unbekannte Auftragsart #{@mode}"
		end
		@konto		= nil #Konto.new()
		@buchungen	= []
		@sumKonto		= 0 #Prüfsummen
		@sumBLZ		= 0 #Prüfsummen
		@sumBetrag	= 0 #Prüfsummen
		@zweck		= "ABBUCHUNG/GUTSCHRIFT"	#Default-Text
		@betragPos	= true	#alle Beträge sind positiv. Variable wird mit erstem Eintrag geändert
		#Nachdem DTA-Datei geschrieben, darf nichts mehr angefügt werden (kein Unterschied DTA/Belegblatt)
		#Dieses Kennzeichen garantiert es.
		@closed		= false
    #DTAUS hat laut Definition keine Lineseps. Zum testen aber ganz praktisch.
		@sep			= ""	#DTAUS hat laut Definition keine Lineseps. Zum testen aber ganz praktisch.
	end
	#	Übergabe der eigenen Kontodaten als Objekt der Klasse Konto
	def konto=( konto )
		@konto = konto
		raise "Konto hat falschen Typ" if ! @konto.kind_of?( Konto )
	end
	#Definieren eines Default-Zwecks
	def zweck=( text )
		raise "zweck hat falschen Typ" if ! text.kind_of?( String )
		@zweck	= text
	end	
	#DTAUS hat laut Definition keine Lineseps. 
	#Zum testen ist dies aber ganz praktisch.
  #
  # DTAUS#sep = "\n"
	attr_accessor :sep
=begin rdoc  
Eine Buchung hinzufügen. 

Es wird geprüft, ob das Vorzeichen identisch mit den bisherigen Vorzeichen ist.
=end
	def add ( buchung )
		raise "Buchung wird hinzugefügt nach Dateierstellung" if @closed
		#Die erste Buchung bestimmt, ob alle Beträge positiv oder negativ sind.
		if @buchungen == []		
			@betragPos	= buchung.positiv?	#alle Beträge sind positiv. Variable wird mit erstem Eintrag geändert
		end
		if @betragPos != buchung.positiv?
			raise "Das Vorzeichen wechselte"
		end
		@buchungen << buchung 
	end
	#Schreiben der DTA-Datei
	def dtaDatei(filename ='DTAUS0.TXT')
		@closed = true	#kein weiteres Zufügen erlaubt
		file = open( filename, 'w')

		@sumKonto	= 0 #Prüfsummen
		@sumBLZ		= 0 #Prüfsummen
		@sumBetrag	= 0 #Prüfsummen
		@buchungen.each{ |b|
			@sumKonto	+= b.konto.nummer
			@sumBLZ	+= b.konto.blz
			@sumBetrag+= b.betrag
		}
		file << dataA( )    #Lastschriften Kunde/Gutschrift Kunde
		@buchungen.each{ |buchung|
			if @typ == 'LK'
				dataC( buchung, '05000', file ) #Lastschrift des Einzugsermächtigungsverfahren 
			elsif @typ == 'GK'
				dataC( buchung, '51000', file ) #Überweisungs-Gutschrift 
			else
				raise 'unbekannter Buchungs-Typ'
				ignoriert += 1
			end
		}
		file	<< dataE()
		file.close()
		print "#{filename} erstellt , #{@buchungen.size} Einträge\n"
	end

#Erstellen A-Segment der DTAUS-Datei
#Aufbau des Segments:
# Nr.	Start	Länge 		Beschreibung 
# 1 	0  		4 Zeichen  	Länge des Datensatzes, immer 128 Bytes, also immer "0128" 
# 2 	4  		1 Zeichen  	Datensatz-Typ, immer 'A' 
# 3 	5  		2 Zeichen  	Art der Transaktionen 
#						"LB" für Lastschriften Bankseitig 
#						"LK" für Lastschriften Kundenseitig 
#						"GB" für Gutschriften Bankseitig 
#						"GK" für Gutschriften Kundenseitig  
# 4 	7  		8 Zeichen  	Bankleitzahl des Auftraggebers 
# 5 	15  	8 Zeichen  	CST, "00000000", nur belegt, wenn Diskettenabsender Kreditinstitut 
# 6 	23  	27 Zeichen  Name des Auftraggebers 
# 7 	50  	6 Zeichen  	aktuelles Datum im Format DDMMJJ 
# 8 	56  	4 Zeichen  	CST, "    " (Blanks) 
# 9 	60  	10 Zeichen  Kontonummer des Auftraggebers 
# 10 	70  	10 Zeichen  Optionale Referenznummer 
# 11a 80  	15 Zeichen  Reserviert, 15 Blanks 
# 11b 95  	8 Zeichen  	Ausführungsdatum im Format DDMMJJJJ. Nicht jünger als Erstellungsdatum (A7), jedoch höchstens 15 Kalendertage später. Sonst Blanks. 
# 11c 103  	24 Zeichen  Reserviert, 24 Blanks 
# 12 	127  	1 Zeichen  	Währungskennzeichen 
#						" " = DM 
#						"1" = Euro  
#    Insgesamt 128 Zeichen 
	def dataA( )
		data = '0128'
		data += 'A'				#Segment
		data += @typ				#Lastschriften Kunde
		data += '%8i' % @konto.blz #.rjust(8)	#BLZ
		data += '%08i' % 0                 #belegt, wenn Bank
		data += '%-27.27s' % @konto.dtaname
		data += @datum.strftime("%d%m%y")	#aktuelles Datum im Format DDMMJJ 
#		puts @datum.strftime("%d%m%Y")	#aktuelles Datum im Format DDMMJJ 
		data += ' ' * 4  #bankinternes Feld
		data += '%010i' % @konto.nummer
		data += '%010i' % 0 #Referenznummer
		data += ' '  * 15  #Reserve
		data += '%8s' % @datum.strftime("%d%m%Y")	   #Ausführungsdatum (ja hier 8 Stellen, Erzeugungsdat. hat 6 Stellen)
		data += ' ' * 24   #Reserve
		data += '1'   #Kennzeichen Euro
		print "DTAUS: Längenfehler A (#{data.size} <> 128)\n" if data.size != 128
		return data
	end #dataA
#Erstellen C-Segmente (Buchungen mit Texten) der DTAUS-Datei
#Aufbau:		
#	Nr.	St	Länge		Beschreibung 
#	1 	0  	4 Zeichen  	Länge des Datensatzes, 187 + x * 29 (x..Anzahl Erweiterungsteile) 
#	2 	4  	1 Zeichen  	Datensatz-Typ, immer 'C' 
#	3 	5  	8 Zeichen  	Bankleitzahl des Auftraggebers (optional) 
#	4 	13  8 Zeichen  	Bankleitzahl des Kunden 
#	5 	21  10 Zeichen  Kontonummer des Kunden 
#	6 	31  13 Zeichen  Verschiedenes 
#			1. Zeichen: "0" 
#			2. - 12. Zeichen: interne Kundennummer oder Nullen 
#			13. Zeichen: "0" 
#			Die interne Nummer wird vom erstbeauftragten Institut zum endbegünstigten Institut weitergeleitet. Die Weitergabe der internenen Nummer an den Überweisungsempfänger ist der Zahlstelle freigestellt.  
#	7 	44  5 Zeichen  Art der Transaktion (7a: 2 Zeichen, 7b: 3 Zeichen) 
#			"04000" Lastschrift des Abbuchungsauftragsverfahren 
#			"05000" Lastschrift des Einzugsermächtigungsverfahren 
#			"05005" Lastschrift aus Verfügung im elektronischen Cash-System 
#			"05006" Wie 05005 mit ausländischen Karten 
#			"51000" Überweisungs-Gutschrift 
#			"53000" Überweisung Lohn/Gehalt/Rente 
#			"5400J" Vermögenswirksame Leistung (VL) ohne Sparzulage 
#			"5400J" Vermögenswirksame Leistung (VL) mit Sparzulage 
#			"56000" Überweisung öffentlicher Kassen 
#			Die im Textschlüssel mit J bezeichnete Stelle, wird bei Übernahme in eine Zahlung automatisch mit der jeweils aktuellen Jahresendziffer (7, wenn 97) ersetzt.  
#	8 	49  1 Zeichen  Reserviert, " " (Blank) 
#	9 	50  11 Zeichen  Betrag 
#	10 	61  8 Zeichen  Bankleitzahl des Auftraggebers 
#	11 	69  10 Zeichen  Kontonummer des Auftraggebers 
#	12 	79  11 Zeichen  Betrag in Euro einschließlich Nachkommastellen, nur belegt, wenn Euro als Währung angegeben wurde (A12, C17a), sonst Nullen 
#	13 	90  3 Zeichen  Reserviert, 3 Blanks 
#	14a 93  27 Zeichen  Name des Kunden 
#	14b 120  8 Zeichen  Reserviert, 8 Blanks 
#    Insgesamt 128 Zeichen
#    
#	15 128  27 Zeichen  Name des Auftraggebers 
#	16 155  27 Zeichen  Verwendungszweck 
#	17a 182  1 Zeichen  Währungskennzeichen 
#			" " = DM 
#			"1" = Euro  
#	17b 183  2 Zeichen  Reserviert, 2 Blanks 
#	18 185  2 Zeichen  Anzahl der Erweiterungsdatensätze, "00" bis "15" 
#	19 187  2 Zeichen  Typ (1. Erweiterungsdatensatz) 
#			"01" Name des Kunden 
#			"02" Verwendungszweck 
#			"03" Name des Auftraggebers  
#	20 189  27 Zeichen  Beschreibung gemäß Typ 
#	21 216  2 Zeichen  wie C19, oder Blanks (2. Erweiterungsdatensatz) 
#	22 218  27 Zeichen  wie C20, oder Blanks 
#	23 245  11 Zeichen  11 Blanks 
#	Insgesamt 256 Zeichen, kann wiederholt werden (max 3 mal)
	def dataC( buchung, zahlungsart, file)
		#Erweiterungssegmente für lange Namen, Texte...
		erweiterungen = []  #('xx', 'inhalt') xx: 01=Name 02=Verwendung 03=Name
		# 1. Satzabschnitt
		#data1 = '%4i' % ?? #Satzlänge kommt später
		data1 = 'C'
		data1 +=  '%08i' % 0  #freigestellt
		data1 +=  '%08i' % buchung.konto.blz
		data1 +=  '%010i' % buchung.konto.nummer
		data1 +=  '0%011i0' % buchung.konto.kunnr   #interne Kundennummer
		data1 +=  zahlungsart 
		data1 +=  ' ' #bankintern
		data1 +=  '0' * 11   #Reserve
		data1 +=  '%08i' % @konto.blz
		data1 +=  '%010i' % @konto.nummer
		data1 +=  '%011i' % buchung.betrag #Betrag in Euroeinschl. Nachkomme
		data1 +=  ' ' * 3
		#Name unseren Mitgliedes = Begünstigte/Zahlungspflichtiger
		data1 +=  '%-27.27s' % buchung.konto.dtaname
		erweiterungen << ['01', buchung.konto.dtaname[27..999] ] if buchung.konto.dtaname.size > 27
		data1 +=  ' ' * 8
		#Einfügen erst möglich, wenn Satzlänge bekannt

		# 2. Satzabschnitt
		data2 = "%27.27s" % @konto.dtaname
		zweck = buchung.dtatext
		#Erste 27 Zeichen
		#Wenn text < 26 Zeichen, dann mit spaces auffüllen.
		#~ data2 +=  '%27.27s' % zweck
		data2 +=  zweck[0..26].ljust(27)
		zweck = zweck[27..999] 
		while zweck and zweck.size > 0 and erweiterungen.size < 13
			erweiterungen << ['02', zweck.ljust(27) ] 
			zweck = zweck[27..999]
		end
		erweiterungen << ['03', @konto.dtaname[27..999] ] if @konto.dtaname.size > 27
    
		#puts erweiterungen
		data2 +=  '1'     #Währungskennzeichen
		data2 +=  ' ' * 2
		# Gesamte Satzlänge ermitteln ( data1(+4) + data2 + Erweiterungen )
		data1 = "%04i#{data1}" % ( data1.size + 4 + data2.size+ 2 + erweiterungen.size * 29 ) 
		print "DTAUS: Längenfehler C/1 #{data1.size}, #{buchung.konto.name}" if data1.size != 128
		file.write(data1 + @sep)
		#Anzahl Erweiterungen anfügen
		data2 +=  '%02i' % erweiterungen.size  #Anzahl Erweiterungsteile
		#Die ersten zwei Erweiterungen gehen in data2,
		#Satz 3/4/5 à 4 Erweiterungen  -> max. 14 Erweiterungen (ich ignoriere möglichen Satz 6)
		erweiterungen  += [ ['00', "" ]  ] * (14 - erweiterungen.size) 
		erweiterungen[0..1].each{ |erw|
			data2 +=  "%2.2s%-27.27s" % [erw[0], DTAUS.convert_text(erw[1]) ]
		}
		data2 +=  ' ' * 11
		print "DTAUS: Längenfehler C/2 #{data2.size}, #{buchung.konto.name}" if data2.size != 128
		file.write( data2 + @sep)
		#Erstellen der Texterweiteungen à vier Stück
		dataErweiterung( erweiterungen[2..5], file )
		dataErweiterung( erweiterungen[6..9], file )
		dataErweiterung( erweiterungen[10..13], file )
	end	#dataC
	def dataErweiterung( erweiterungen, file )
		raise "Nur #{erweiterungen.size} Erweiterungstexte, 4 benötigt" if erweiterungen.size != 4
		data3 =	"%2.2s%-27.27s" % [erweiterungen[0][0], erweiterungen[0][1] ]
		data3 +=	"%2.2s%-27.27s" % [erweiterungen[1][0], erweiterungen[1][1] ]
		data3 +=	"%2.2s%-27.27s" % [erweiterungen[2][0], erweiterungen[2][1] ]
		data3 +=	"%2.2s%-27.27s" % [erweiterungen[3][0], erweiterungen[3][1] ]
		data3 += ' ' * 12
		if data3[0..1] != '00' 
			print "DTAUS: Längenfehler C/3 #{data3.size} " if data3.size != 128
			file.write( data3 + @sep)
		end
	end	#dataC
#Erstellen E-Segment (Prüfsummen) der DTAUS-Datei
#Aufbau:
#	Nr.	Start Länge 	Beschreibung 
#	1 	0  	4 Zeichen  	Länge des Datensatzes, immer 128 Bytes, also immer "0128" 
#	2 	4  	1 Zeichen  	Datensatz-Typ, immer 'E' 
#	3 	5  	5 Zeichen  	"     " (Blanks) 
#	4 	10  7 Zeichen  	Anzahl der Datensätze vom Typ C 
#	5 	17  13 Zeichen  Kontrollsumme Beträge 
#	6 	30  17 Zeichen  Kontrollsumme Kontonummern 
#	7 	47  17 Zeichen  Kontrollsumme Bankleitzahlen 
#	8 	64  13 Zeichen  Kontrollsumme Euro, nur belegt, wenn Euro als Währung angegeben wurde (A12, C17a) 
#	9 	77  51 Zeichen  51 Blanks 
#	Insgesamt 128 Zeichen 
	def dataE()
		data = '0128'
		data += 'E'
		data += ' ' * 5
		data += '%07i' % @buchungen.size
		data += '0' * 13 #Reserve
		data += '%017i' % @sumKonto
		data += '%017i' % @sumBLZ
		data += '%013i' % @sumBetrag
		data += ' '  * 51 #Abgrenzung Datensatz
		print "DTAUS: Längenfehler E #{data.size} <> 128" if data.size != 128
		return data
	end

	#Jede dem Geldinstitut gelieferte Diskette muß einen
	#Begleitzettel mit folgenden Mindestangaben enthalten.
	#Bei mehreren Disketten ist für jede Diskette ein
	#Begleitzettel auszuschreiben. 
	#
	#- Begleitzettel 
	#- Belegloser Datenträgeraustausch 
	#- Sammel-Überweisung-/-einziehungsauftrag 
	#- Vol-Nummer der Diskette 
	#- Erstellungsdatum 
	#- Anzahl der Datensätze C (Stückzahl) 
	#- Summe DM der Datensätze C 
	#- Kontrollsumme der Kontonummern der 
	#- Überweisungsempfänger/Zahlungspflichtigen 
	#- Kontrollsumme der Bankleitzahlen der endbegünstigten 
	#- Kreditinstitute/Zahlungsstellen 
	#- Bankleitzahl/Kontonummer des Absenders 
	#- Name, Bankleitzahl/Kontonummer des Empfängers 
	#- Ort, Datum 
	#- Firma, Unterschrift 
	#
	#Sie haben die Pflicht, die Disketten zusätzlich
	#durch Klebezettel mit folgenden Angaben zu kennzeichnen:
	#- Name und Bankleitzahll/Kontonummer des Diskettenabsenders. 
	#- Diskettennummer (VOL-Nummer). 
	#- Dateiname: DTAUS0.TXT 5.25 -und 3.5 Diskette. 
	def begleitblatt( filename = nil )
		text = %Q|
Begleitzettel, Belegloser Datenträgeraustausch: #{@typText}
Erstellungsdatum:
	#{@datum.strftime("%d.%m.%Y")}
Überweisungsempfänger/Zahlungspflichtigen
	#{@konto.name}
Kontonummer des Absenders:
	#{@konto.nummer}
Bankleitzahl des Absenders:
	#{@konto.blz}
Bank:
	#{@konto.bank}
Anzahl der Datensätze C (Stückzahl):
	#{@buchungen.size}
Summe Euro-Cent der Datensätze C:
	#{@sumBetrag}
Kontrollsumme der Kontonummern:
	#{@sumKonto}
Kontrollsumme der Bankleitzahlen der Endbegünstigten:
	#{@sumBLZ}
Ort, Datum 

Firma, Unterschrift
|
		if filename
			file = File.new( filename, 'w')
			file.puts( text )
			file.close()
		end
		return text
	end
	def buchungsuebersicht()
		text = "Buchungsübersicht\n"
		@buchungen.each{ |b|
		text += "#{b.betrag}€-Cent\t#{b.konto.nummer}\t#{b.konto.blz}\t#{b.konto.name}\n"
		}
		return text
	end
	#Diese Routine liefert ein TeX-Fragment zurück mit einem Begleitblatt.
	#Der Inhalt ist derselbe wie von der Mathode begleitblatt erzeugt wird.
	#Es wird als Klasse scrlttr2 angenommen.
	#Informationen zu TeX und LaTeX findet sich unter http://www.dante.de
	def begleitblatt_tex()
	#fixme: \ als Standrad nehmen analog regexp.escape
		text = <<ENDE
|begin{letter}{#{@konto.bank}\\\\\\
	#{@konto.bankStrasse}~\\\\\\
	#{@konto.bankPLZ} #{@konto.bankOrt}
	}
|title{Begleitzettel, Belegloser Datenträgeraustausch #{@typText}}
|opening{~}
|begin{description}
|item[Erstellungsdatum:]
	#{@datum.strftime("%d.%m.%Y")}
|item[Überweisungsempfänger/Zahlungspflichtigen]
	#{@konto.name}
|item[Kontonummer des Absenders:]
	#{@konto.nummer}
|item[Bankleitzahl des Absenders:]
	#{@konto.blz}
|item[Bank:]
	#{@konto.bank}
|item[Zweck:]
	#{@zweck}
|item[Anzahl der Datensätze C (Stückzahl):]
	#{@buchungen.size}
|item[Summe Euro der Datensätze C:]
	#{euro(@sumBetrag)}
|item[Kontrollsumme der Kontonummern:]
	#{@sumKonto}
|item[Kontrollsumme der Bankleitzahlen der Endbegünstigten:]
	#{@sumBLZ}
|end{description}
|closing{~}
|end{letter}
ENDE
		return text.tr!('|', '\\')
	end #begleitblatt_tex
	#Diese Routine liefert eine Tabelle mit allen Buchungen zurück.
	#Verwendet die Pakete hyperref und longtable
	def buchungsuebersicht_tex()
		text = <<ENDE
|begin{longtable}{p{40mm}llrp{60mm}}
|multicolumn{5}{c}{|textbf{Buchungsübersicht #{@typText}}}||
	Name & Konto & BLZ & Betrag & |||hline|endhead
|multicolumn{5}{r}{Fortsetzung nächste Seite}|endfoot
|endlastfoot
ENDE
		text.tr!('|', '\\')
		#~ #Sort nach?
		@buchungen.each{ |b|
			text	+=	"\\hyperlink{MNr:#{b.konto.kunnr}}{#{b.konto.name}}\t&"
			text	+=	"\t #{b.konto.nummer}& #{b.konto.blz} & \\euros{#{euro(b.betrag)}}"
			text	+=	"&#{b.text}"
			text	+=	"\\\\\n"
		}
		text += "\\hline\nSumme & \t \t#{@sumKonto}\t& #{@sumBLZ}\t & \\euros{#{euro(@sumBetrag)}}\\\\\n"
		text += "\\end{longtable}\n"
		return text
	end
	def euro (betrag)
		f = betrag.to_f / 100
		return "%8.2f" % f
	end
	def tex_file( filename = nil )
		tex = <<ENDE
|documentclass[10pt,german]{scrlttr2}
%|usepackage{booktabs}%%leider nicht mit longtable
%|usepackage{graphicx}
|usepackage{babel}
|usepackage{hyperref}
|usepackage{tabularx}
|usepackage{longtable}
|usepackage{units}
|usepackage{isodate}
|usepackage[right,eurosym]{eurofont}

|newlength{|betragsbreite}%%Breite des Endsummen (Fahrten/EP)
|setlength{|betragsbreite}{15mm}

%|nexthead{|fromname -|thepage-}%scrlettr
|nexthead{|usekomavar{fromname} -|thepage-}%scrlettr2

|begin{document}
ENDE
		tex.tr!('|', '\\')
		tex += begleitblatt_tex()
		tex += "\n\\pagebreak\n\\nexthead{}\n"
		tex += buchungsuebersicht_tex()
		tex += "\n\\end{document}"
		
		if filename != nil
			file = File.new( filename, 'w')
			file.puts( tex)
			file.close
		end
		return tex
	end
	#Zeichen umsetzen gemäss DTA-Norm
	def DTAUS.convert_text( text )
		text = text.to_s()
		puts "Text kein String >#{text}< (#{text.class})" if ! text.kind_of?( String )
		text = text.upcase()
		text = text.gsub('Ä', 'AE')
		text = text.gsub('Ü', 'UE')
		text = text.gsub('Ö', 'OE')
		text = text.gsub('ä', 'AE')
		text = text.gsub('ü', 'UE')
		text = text.gsub('ö', 'OE')
		text = text.gsub('ß', 'SS')
		return text = text.strip
	end
	#
	private	:dataA, :dataC, :dataE
end	#class dtaus

#
#Die Klasse erlaubt ein Filegesteuertes Anlegen einer DTA-Datei.
#Zwei Dateien sind notendig:
#-	Kontendaten
#	Schnittstelle siehe DTAUS_from_File.new
#-	Buchungsdaten
#Wird von start_from_desktop() gerufen.
class DTAUS_from_File	< DTAUS	
	#Statt einzelner Parameter werden die Kontendaten per File übergeben.
	#Die Datei hat das Format:
	#	typ:LK
	#	blz:99988811
	#	konto:123456
	#	bank:Nord-Ostschwäbische Sandbank
	#	name:Jodelverein Holladriö 1863 e.V.
	#	zweck:Mitgliedsbeitrag 2003
	def initialize( filename, typ=nil, splitter = ':' )
		begin
			puts "Datei <#{filename}> nicht gefunden"; 
			exit 
		end if ! File.exist?( filename )
		k = File.new(filename).readlines
		@splitter = splitter
		data = {}
		k.each{ |l|
			next if ! l	#Check empty lines
			l = l.split(@splitter)
			data[l[0].strip()] = l[1].strip()
		}
		[ 'typ', 'konto', 'blz', 'name' ].each{ |key|
			begin
				puts "Keyfeld #{key} fehlt" 
				exit
			end if ! data.has_key?(key)
		}
		super( data['typ'] )
		if typ and data['typ'] and data['typ'] != typ
			puts "Zahlungstyp aus Kontodatei:	#{data['typ']}"
			puts "Zahlungstyp aus Aufruf:		#{typ}"
			exit
		end
		self.konto = Konto.new( data['konto'], data['blz'], data['name'], data['bank'] )
		@konto.bankStrasse	= data['bankstrasse'] 
		@konto.bankPLZ	= data['bankplz'] 
		@konto.bankOrt		= data['bankort'] 
		self.zweck = data['zweck'] if data['zweck']
	end	
	#Einlesen von Buchungen aus einer Datei
	#Die Buchungen sind in einer Datei mit den folgenen Feldern:
	#- nachname
	#- vorname
	#- kunnr		interne Kundennummer
	#- konto
	#- blz
	#- bank		Name der Bank
	#- betrag	positiver Betrag in Euro
	#- zweck		(optional) abweichender Text zu Kontodaten
	def lese_buchungen( filename )
		begin
			puts "Datei <#{filename}> nicht gefunden"; 
			exit 
		end if ! File.exist?( filename )
		k = File.new(filename).readlines
		k.each{ |l|
			next if ! l	#Check empty lines
			next if l.strip[0..0] == '#' or l.strip[0..0] == '%'
			l = l.split(@splitter)	#Name:Vorname:MNr:Kto:BLZ:Bank:Beitragshöhe
			zweck = l[7]
			zweck = @zweck if ! zweck
			add Buchung.new(
				Konto.new(		l[3],		#Kontonummer
							l[4],		#BLZ
							l[0] + ' ' + l[1],	#Name
							l[5],		#bank
							l[2]		#Mitglieds/Kundennummer
						),	
				l[6],		#Betrag
				zweck )	#Zweck
		}
	end
end	#DTAUS_from_File

#Analyse der ARGV wenn das Programm vom Desktop gestartet.
#Verwendet DTAUS_from_File.
def start_from_desktop( )

	#Defaults definieren:
	fileKonto		= ''
	fileBuchungen	= ''
	#~ fileKonto		= 'test_Konto.txt'
	#~ fileBuchungen	= 'Test_buchung.txt'
	typ			= nil	#Kann auch aus File kommen
	dtaname		= 'DTAUS0.TXT'
	begleitblatt	= 'Begleitblatt.txt'
	linefeed			= false #Kann mehrheitlich verarbeitet werden
	splitter			= ':'

	ARGV.options{|opt|
		opt.banner =  "dtaus.rb [-t Typ] -k Konto -b Buchungen"
		opt.on( '-t', "--typ", ['LK', 'GK'], :REQUIRED, <<DESCR
Typ der Überweisung. 
	Werte:
		LK (Lastschrift Kunde)
		GK (Gutschrift Kunde)
	Wird der Typ auch in der Kontodatei definiert (Option -k) wird auf Gleichheit geprüft
DESCR
		){ |wert|
			typ = wert
		}
		opt.on( '-k', "--konto KONTODATEN", :REQUIRED, <<DESCR
Filename der eigenen Kontodaten
		Beispiel:
			typ:LK
			blz:99988811
			konto:123456
			bank:Nord-Ostschwaebische Sandbank
			bankstrasse:Kieselweg 3
			bankplz:0815
			bankort:Felsblock
			name:Jodelverein Holladrioe 1863 e.V.
			zweck:Mitgliedsbeitrag 2003
		Der Typ ist LK oder GK. Siehe Option -t
		zweck ist ein optionaler Default-Text, der verwendet wird, 
		falls eine Buchung keinen Text hat.
		Die Adressdaten der Bank sind optional und werdezum erzeugen 
		des Begleitblatts verwendet
DESCR
		){|wert|
			fileKonto = wert
		}
		opt.on('-b', "--buchung BUCHUNGSDATEN",	:REQUIRED, <<DESCR
Filename der Buchungen
		Jede Buchung ist in einer Zeile mit den folgenen Feldern:
			- nachname
			- vorname
			- kunnr		interne Kundennummer
			- konto
			- blz
			- bank		Name der Bank
			- betrag	positiver Betrag in Euro
			- zweck		(optional) abweichender Text zu Kontodaten
DESCR
		){|wert|
			fileBuchungen = wert
		}
		opt.on('-d', "--dtaus [DTAUSNAME]",	 
					"Name der zu erzeugenden DTAUS-Datei. Default: DTAUS0.TXT"
		){|wert|
			dtaname = wert
		}
		opt.on('-c', "--[no-]cr",	 
					"Mit/Ohne Zeilenschaltung"
		){|wert|
			linefeed = wert
		}
		opt.on('-p',"--begleitblatt [BEGLEITBLATT]", :REQUIRED,
				<<DESCR
Name des zu erzeugenden Begleitblattes
		Default: Begleitblatt.txt
		Enthaelt der Dateiname ein .tex, so wird eine LaTeX-Datei erstellt.
DESCR
		){|wert|
			begleitblatt = wert
		}
		opt.on('-s', "--splitter [splitter]",	 
					"Feldtrenner in den Datei. Default: ':'"
		){|wert|
			splitter = wert
		}
		
	}
	
  begin
	ARGV.parse!
  rescue OptionParser::InvalidOption => err
    puts "Fehler beim Aufruf: #{err}"
    exit
  end
	
	if fileKonto == '' or fileBuchungen == ''
		puts "Keine Dateien übergeben"
		exit
	end
	
	dta	= DTAUS_from_File.new( fileKonto, typ, splitter )
	linefeed ? dta.sep = "\n" : dta.sep = ''
	dta.lese_buchungen( fileBuchungen )
	dta.dtaDatei( dtaname )
	if /\.tex/ =~ begleitblatt
		dta.tex_file( begleitblatt )
	else
		dta.begleitblatt( begleitblatt )
	#	dta.buchungsuebersicht()
	end
	puts 	dta.begleitblatt( )
end	#start_from_desktop()

start_from_desktop( ) if __FILE__ == $0
