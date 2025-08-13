#!/usr/bin/env ruby

# Test script to verify notarized document extraction
require_relative 'config/environment'

# Test text with notarized format (your example)
notarized_text = <<-TEXT
LEAVE AND LICENSE AGREEMENT
Department of Registration and Stamps
Government of Maharashtra

This agreement is made and executed on at Pune
Between,
1)Nitin Prem Bhalla, PAN: AJPPB9672B, Age: 42 Years, Gender: Male, Occupation:Others, Mobile No:
7020183782, Residing at: S.No.100 and 101, Flat no.G 301,alcove opp. rajveer palace Pune City
Pimpri Colony Pune, NA, Pune City, Pune, MAHARASHTRA, Pin code- 411017 through P.O.A Sarika
Premkumar Bhalla, Age: 46 Years, Gender: Female, Occupation:Others, Mobile No:7020183782 ,
Residing at:ward no 1 bhalla niwas college road Shrirampur Shrirampur Ahmadnagar, Pin code -
413709
HEREINAFTER called the Licensor (which expression shall mean and include the Licensor above named
and also their respective heirs, successors, assigns, executors and administrators)
AND
1)Rajat Saini , PAN:GMMPS4232L, Age:31 Years, Gender:Male, Occupation:Others, Mobile
No.7017629538, Residing at:f-452/5 Shafipur Roorkee Haridwar Uttarakhand, NA, Roorkee,
Haridwar, UTTARAKHAND, , Pin code -247667
HEREINAFTER called the Licensee (which expression shall mean and include only Licensee above
named).
WHEREAS the Licensor is absolutely seized and possessed of and or otherwise well and sufficiently entitled
to all that constructed portion being unit described in Schedule I hereunder written and are hereafter for
the sake of brevity called or referred to as Licensed Premises and is/are desirous of giving the said
premises on Leave and License basis under Section 24 of the Maharashtra Rent Control Act, 1999.
AND WHEREAS the Licensee herein is in need of temporary premises for Residential use has/have
approached the Licensor with a request to allow the Licensee herein to use and occupy the said premises
on Leave and License basis for a period of 11 months commencing from 20/04/2025 and ending on
19/03/2026, on terms and subject to conditions hereafter appearing.
AND WHEREAS the Licensor have agreed to allow the Licensee herein to use and occupy the said Licensed
premises for his aforesaid Residential purposes only, on Leave and License basis for above mentioned
period, on terms and subject to conditions hereafter appearing.
TEXT

puts "Testing Notarized Document Extraction"
puts "=" * 50

# Test notarized document extraction
puts "\nTesting notarized document extraction:"
extractor = PdfDataExtractorService.new(notarized_text)
result = extractor.extract_all_data

puts "Document Type: #{result[:document_type]}"
puts "Licensor: #{result[:licensor]}"
puts "Licensee: #{result[:licensee]}"
puts "Start Date: #{result[:start_date]}"
puts "End Date: #{result[:end_date]}"
puts "Agreement Period: #{result[:agreement_period]}"

puts "\n✅ Test completed!"

# Expected results:
puts "\n📋 Expected Results:"
puts "Document Type: NOTARIZED AGREEMENT"
puts "Licensor: Nitin Prem Bhalla"
puts "Licensee: Rajat Saini" 
puts "Start Date: 2025-04-20"
puts "End Date: 2026-03-19"
