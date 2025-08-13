#!/usr/bin/env ruby

# Test script to verify document type detection
require_relative 'config/environment'

# Test text with notarization
notarized_text = <<-TEXT
LEAVE AND LICENSE AGREEMENT
Department of Registration and Stamps
Government of Maharashtra

This agreement is made and executed on at Pune
Between,
1)Nitin Prem Bhalla, PAN: AJPPB9672B, Age: 42 Years...
TEXT

# Test text without notarization
regular_text = <<-TEXT
LEAVE AND LICENSE AGREEMENT
This agreement is made and executed on at Pune
Between,
1)Nitin Prem Bhalla, PAN: AJPPB9672B, Age: 42 Years, Gender: Male, Occupation:Others, Mobile No:
7020183782, Residing at: S.No.100 and 101, Flat no.G 301,alcove opp. rajveer palace Pune City
HEREINAFTER called the Licensor
AND
1)Rajat Saini , PAN:GMMPS4232L, Age:31 Years, Gender:Male, Occupation:Others, Mobile
No.7017629538, Residing at:f-452/5 Shafipur Roorkee Haridwar Uttarakhand
HEREINAFTER called the Licensee
for a period of 11 months commencing from 20/04/2025 and ending on 19/03/2026
TEXT

puts "Testing Document Type Detection"
puts "=" * 50

# Test notarized document
puts "\n1. Testing notarized document:"
extractor1 = PdfDataExtractorService.new(notarized_text)
result1 = extractor1.extract_all_data
puts "Document Type: #{result1[:document_type]}"
puts "Licensor: #{result1[:licensor]}"
puts "Licensee: #{result1[:licensee]}"
puts "Start Date: #{result1[:start_date]}"
puts "End Date: #{result1[:end_date]}"

# Test regular document
puts "\n2. Testing regular document:"
extractor2 = PdfDataExtractorService.new(regular_text)
result2 = extractor2.extract_all_data
puts "Document Type: #{result2[:document_type]}"
puts "Licensor: #{result2[:licensor]}"
puts "Licensee: #{result2[:licensee]}"
puts "Start Date: #{result2[:start_date]}"
puts "End Date: #{result2[:end_date]}"

puts "\n✅ Test completed!"
