#!/usr/bin/env ruby

require_relative 'app/services/pdf_data_extractor_service'

# Sample PDF content from the user
sample_content = <<~PDF_CONTENT
  RENT AGREEMENT

  Licensor:
  MRS. NIRALI SHARMA

  Flat No.: 5-B
  Building Name: / Jeevan Sandhya
  Road: Gandhi Road
  Sector: 13
  District: Gandhinagar
  State: Gujarat
  Pin: 382013

  Licensee:
  MR. ROHAN JOSHI

  Flat No.: 5-B
  Building Name: / Jeevan Sandhya
  Road: Gandhi Road
  Sector: 13
  District: Gandhinagar
  State: Gujarat
  Pin: 382013

  Address:
  5-B Jeevan Sandhya, Gandhi Road, Sector 13, Gandhinagar, Gujarat - 382013

  Agreement Date: 15/03/2024
  Agreement Period: 11 Months

  This Agreement is executed on 15th March 2024 between the Licensor and Licensee for a period of 11 months.
PDF_CONTENT

puts "=" * 60
puts "TESTING PDF DATA EXTRACTION"
puts "=" * 60

extractor = PdfDataExtractorService.new(sample_content)
extracted_data = extractor.extract_all_data

puts "\nExtracted Data:"
puts "-" * 40

puts "Licensor: #{extracted_data[:licensor] || 'Not found'}"
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
