#!/usr/bin/env ruby

# Test script for Property Description Corporation address extraction
require 'bundler/setup'
require_relative 'config/environment'

# Test content with the Property Description Corporation pattern
test_content = <<~EOF
  Sample License Agreement

  Licensor: John Doe Property Management
  
  Property Description Corporation: Pune, Other details: Apartment/Flat No:-, Floor No:-, Building
  Name:/Pandurang Nagar , Block Sector:Pune-411014, Road:Pune City,
  City:Yevalewadi, District:Pune, Survey Number : 73/1, Leave and License Months:11

  Licensee: Jane Smith

  Agreement Date: 01/04/2025
  Period: 11 Months commencing from 01/04/2025 and ending on 28/02/2026
EOF

puts "Testing Property Description Corporation address extraction..."
puts "=" * 60

extractor = PdfDataExtractorService.new(test_content)
extracted_data = extractor.extract_all_data

puts "Original content:"
puts test_content
puts "\n" + "=" * 60

puts "\nExtracted Data:"
puts "Licensor: #{extracted_data[:licensor]}"
puts "Licensee: #{extracted_data[:licensee]}"
puts "Address: #{extracted_data[:address]}"
puts "Agreement Date: #{extracted_data[:agreement_date]}"
puts "Agreement Period: #{extracted_data[:agreement_period]}"

puts "\n" + "=" * 60
puts "Expected Address Format:"
puts "Corporation: Pune, Other details: Apartment/Flat No:-, Floor No:-, Building Name:/Pandurang Nagar , Block Sector:Pune-411014, Road:Pune City, City:Yevalewadi, District:Pune, Survey Number : 73/1, Leave and License Months:11"

puts "\n" + "=" * 60
puts "Test Result:"
expected_start = "Corporation: Pune, Other details:"
if extracted_data[:address]&.start_with?(expected_start)
  puts "✅ SUCCESS: Address extraction working correctly!"
  puts "✅ Address starts with expected 'Corporation: Pune, Other details:'"
else
  puts "❌ FAILED: Address extraction not working as expected"
  puts "❌ Expected to start with: #{expected_start}"
  puts "❌ Actual result: #{extracted_data[:address]}"
end
puts "Licensee: #{extracted_data[:licensee] || 'Not found'}"
puts "Address: #{extracted_data[:address] || 'Not found'}"
puts "Agreement Date: #{extracted_data[:agreement_date] || 'Not found'}"
puts "Agreement Period: #{extracted_data[:agreement_period] || 'Not found'}"

puts "\nFiltered Data:"
puts "-" * 40
puts extracted_data[:filtered_data] || 'No filtered data'

puts "\n" + "=" * 60
puts "TESTING COMPLETE"
puts "=" * 60
