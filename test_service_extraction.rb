#!/usr/bin/env ruby
require_relative 'config/environment'

# Test the PdfDataExtractorService with sample text
sample_text = %{
KNOW ALL MEN BY THESE PRESENTS that Mr.GADKARI SANDEEP SATISH (hereinafter called "the Licensor") And Mr.Singh Shubham (hereinafter called "the Licensee")
have entered into this License Agreement on the terms and conditions set forth below:

Property Details: Flat 201, Building ABC, Sector 15, Pune-411014, Road: Main Road, City: Pune, District: Pune

Period: 11 months commencing from 01/01/2024 to 30/11/2024

Agreement Date: 15/12/2023
}

puts "Testing PdfDataExtractorService with sample text..."
puts "Sample text:"
puts sample_text
puts "\n" + "="*50 + "\n"

service = PdfDataExtractorService.new(sample_text)
extracted_data = service.extract_all_data

puts "Extracted data:"
extracted_data.each do |key, value|
  puts "#{key}: #{value.inspect}"
end

puts "\n" + "="*50 + "\n"
puts "Testing complete!"
