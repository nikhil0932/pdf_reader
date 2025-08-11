#!/usr/bin/env ruby
require_relative 'config/environment'

# Test the PdfDataExtractorService with traditional structured text
traditional_text = %{
This License Agreement is entered into between:

Licensor:
Mr. John Smith

Licensee:
Ms. Jane Doe

Address:
Flat 123, Building XYZ, Sector 10, Mumbai-400001

Agreement Date: 01/01/2024

Period: 12 months from 01/01/2024 to 31/12/2024
}

puts "Testing PdfDataExtractorService with traditional structured text..."
puts "Sample text:"
puts traditional_text
puts "\n" + "="*50 + "\n"

service = PdfDataExtractorService.new(traditional_text)
extracted_data = service.extract_all_data

puts "Extracted data:"
extracted_data.each do |key, value|
  puts "#{key}: #{value.inspect}"
end

puts "\n" + "="*50 + "\n"
puts "Testing complete!"
