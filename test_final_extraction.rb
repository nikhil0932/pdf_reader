#!/usr/bin/env ruby
require_relative 'config/environment'

# Test edge cases and final verification
test_scenarios = [
  {
    name: "Main scenario - should extract correctly",
    text: %{KNOW ALL MEN BY THESE PRESENTS that Mr.GADKARI SANDEEP SATISH (hereinafter called "the Licensor") And Mr.Singh Shubham (hereinafter called "the Licensee")}
  },
  {
    name: "Empty scenario - should return nil",
    text: %{Some document without clear licensor or licensee information}
  },
  {
    name: "Short names scenario - should return nil",
    text: %{Agreement with Mr.A as Licensor and Mr.B as Licensee}
  },
  {
    name: "Property-related false positive - should return nil", 
    text: %{Property information building road address}
  }
]

puts "Testing final extraction scenarios..."
puts "=" * 50

test_scenarios.each_with_index do |scenario, index|
  puts "\n#{index + 1}. #{scenario[:name]}"
  puts "-" * 40
  puts "Text: #{scenario[:text].strip}"
  
  service = PdfDataExtractorService.new(scenario[:text])
  extracted_data = service.extract_all_data
  
  puts "Results:"
  puts "  Licensor: #{extracted_data[:licensor].inspect}"
  puts "  Licensee: #{extracted_data[:licensee].inspect}"
end

puts "\n" + "=" * 50
puts "Testing complete!"
