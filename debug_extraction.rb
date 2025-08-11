#!/usr/bin/env ruby
require_relative 'config/environment'

# Debug extraction for problematic cases
test_text = "Some document without clear licensor or licensee information"

puts "Debugging extraction for: '#{test_text}'"
puts "=" * 50

service = PdfDataExtractorService.new(test_text)

# Test each primary pattern manually
primary_patterns = [
  /licensor[:\s]+([^\n\r]+)/i,
  /owner[:\s]+([^\n\r]+)/i,
  /landlord[:\s]+([^\n\r]+)/i,
  /lessor[:\s]+([^\n\r]+)/i,
  /licensee[:\s]+([^\n\r]+)/i,
  /tenant[:\s]+([^\n\r]+)/i,
  /lessee[:\s]+([^\n\r]+)/i,
  /occupant[:\s]+([^\n\r]+)/i
]

puts "Testing primary patterns:"
primary_patterns.each_with_index do |pattern, index|
  if match = test_text.match(pattern)
    puts "Pattern #{index + 1} (#{pattern.inspect}): MATCHED - '#{match[1]}'"
  else
    puts "Pattern #{index + 1} (#{pattern.inspect}): NO MATCH"
  end
end

puts "\n" + "=" * 50
puts "Full extraction result:"
extracted_data = service.extract_all_data
puts "Licensor: #{extracted_data[:licensor].inspect}"
puts "Licensee: #{extracted_data[:licensee].inspect}"
