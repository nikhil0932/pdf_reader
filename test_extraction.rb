#!/usr/bin/env ruby

# Test script for Property Description Corporation address extraction
require 'bundler/setup'
require_relative 'config/environment'

# Test content with the Property Description Corporation pattern AND period dates
test_content = <<~EOF
  Sample License Agreement

  Licensor: John Doe Property Management
  
  Property Description Corporation: Pune, Other details: Apartment/Flat No:-, Floor No:-, Building
  Name:/Pandurang Nagar , Block Sector:Pune-411014, Road:Pune City,
  City:Yevalewadi, District:Pune, Survey Number : 73/1, Leave and License Months:11

  Licensee: Jane Smith

  Period: That the Licensor hereby grants to the Licensee herein a revocable leave and license,
  to occupy the Licensed Premises, described in Schedule I hereunder written without creating any
  tenancy rights or any other rights, title and interest in favour of the Licensee for a period of 11
  Months commencing from 01/01/2024 and ending on 30/11/2024

  Agreement Date: 01/04/2025
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
puts "Start Date: #{extracted_data[:start_date]}"
puts "End Date: #{extracted_data[:end_date]}"

puts "\n" + "=" * 60
puts "Expected Results:"
puts "Start Date: 2024-01-01 (from '01/01/2024')"
puts "End Date: 2024-11-30 (from '30/11/2024')"
puts "Address should start with: 'Corporation: Pune, Other details:'"

puts "\n" + "=" * 60
puts "Test Results:"

# Test address extraction
expected_address_start = "Corporation: Pune, Other details:"
address_test = extracted_data[:address]&.start_with?(expected_address_start)

# Test date extraction
start_date_test = extracted_data[:start_date] == Date.new(2024, 1, 1)
end_date_test = extracted_data[:end_date] == Date.new(2024, 11, 30)

puts "✅ Address extraction: #{address_test ? 'PASSED' : 'FAILED'}"
puts "✅ Start date extraction: #{start_date_test ? 'PASSED' : 'FAILED'}"
puts "✅ End date extraction: #{end_date_test ? 'PASSED' : 'FAILED'}"

if address_test && start_date_test && end_date_test
  puts "\n🎉 ALL TESTS PASSED! 🎉"
else
  puts "\n❌ Some tests failed. Check the results above."
  puts "❌ Address result: #{extracted_data[:address]}"
  puts "❌ Start date result: #{extracted_data[:start_date]}"
  puts "❌ End date result: #{extracted_data[:end_date]}"
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
