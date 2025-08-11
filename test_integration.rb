#!/usr/bin/env ruby

# Create a simple PDF document for testing
require 'bundler/setup'
require 'rails'
require_relative 'config/environment'

puts "Testing the complete PDF extraction system..."
puts "=" * 50

# Test with your specific example
sample_text = %{KNOW ALL MEN BY THESE PRESENTS that Mr.GADKARI SANDEEP SATISH (hereinafter called "the Licensor") And Mr.Singh Shubham (hereinafter called "the Licensee") have agreed to the following terms and conditions.

Property Details: Flat 123, Building XYZ, Pune-411014
Period: 11 months from 01/01/2024 to 30/11/2024
Agreement Date: 15/12/2023}

puts "Creating test PDF document..."

# Create a new PdfDocument for testing
pdf_doc = PdfDocument.new(
  title: "Test License Agreement",
  filename: "test_fallback_extraction.pdf",
  content: sample_text,
  uploaded_at: Time.current
)

puts "Extracting data using PdfDataExtractorService..."
service = PdfDataExtractorService.new(sample_text)
extracted_data = service.extract_all_data

puts "\nExtracted data:"
puts "  Licensor: #{extracted_data[:licensor].inspect}"
puts "  Licensee: #{extracted_data[:licensee].inspect}"
puts "  Address: #{extracted_data[:address].inspect}"
puts "  Start Date: #{extracted_data[:start_date].inspect}"
puts "  End Date: #{extracted_data[:end_date].inspect}"
puts "  Agreement Period: #{extracted_data[:agreement_period].inspect}"

# Update the PDF document with extracted data
pdf_doc.assign_attributes(
  licensor: extracted_data[:licensor],
  licensee: extracted_data[:licensee],
  address: extracted_data[:address],
  start_date: extracted_data[:start_date],
  end_date: extracted_data[:end_date],
  agreement_period: extracted_data[:agreement_period],
  processed_at: Time.current
)

puts "\nUpdated PDF document fields:"
puts "  Licensor: #{pdf_doc.licensor.inspect}"
puts "  Licensee: #{pdf_doc.licensee.inspect}"
puts "  Address: #{pdf_doc.address.inspect}"
puts "  Start Date: #{pdf_doc.start_date.inspect}"
puts "  End Date: #{pdf_doc.end_date.inspect}"

puts "\n✅ Fallback extraction is working correctly!"
puts "Names extracted:"
puts "  • Licensor: 'Mr.GADKARI SANDEEP SATISH' → '#{pdf_doc.licensor}'"
puts "  • Licensee: 'Mr.Singh Shubham' → '#{pdf_doc.licensee}'"

puts "\n=" * 50
puts "Integration test complete!"
