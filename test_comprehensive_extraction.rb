#!/usr/bin/env ruby
require_relative 'config/environment'

# Test comprehensive fallback extraction scenarios
test_scenarios = [
  {
    name: "Original sample text",
    text: %{KNOW ALL MEN BY THESE PRESENTS that Mr.GADKARI SANDEEP SATISH (hereinafter called "the Licensor") And Mr.Singh Shubham (hereinafter called "the Licensee")}
  },
  {
    name: "Alternative format 1",
    text: %{This agreement is between Dr.PATEL RAMESH KUMAR (hereinafter called "the Licensor") and Mrs.SHARMA PRIYA DEVI (hereinafter called "the Licensee")}
  },
  {
    name: "Alternative format 2", 
    text: %{Agreement between Ms.JONES SARAH ELIZABETH (hereinafter called "the Licensor") And Mr.BROWN DAVID JAMES (hereinafter called "the Licensee")}
  },
  {
    name: "Traditional structured format",
    text: %{
Licensor:
Mr. John Smith

Licensee:
Ms. Jane Doe
    }
  },
  {
    name: "Empty extraction scenario",
    text: %{Some document without clear licensor or licensee information}
  }
]

puts "Testing comprehensive fallback extraction scenarios..."
puts "=" * 60

test_scenarios.each_with_index do |scenario, index|
  puts "\n#{index + 1}. #{scenario[:name]}"
  puts "-" * 40
  puts "Text: #{scenario[:text].strip}"
  
  service = PdfDataExtractorService.new(scenario[:text])
  extracted_data = service.extract_all_data
  
  puts "Results:"
  puts "  Licensor: #{extracted_data[:licensor].inspect}"
  puts "  Licensee: #{extracted_data[:licensee].inspect}"
  
  # Test the rake task cleanup function as well
  puts "\nTesting clean_extract_data method:"
  
  # Simulate the clean_extract_data method from the rake task
  extracted = { licensor: nil, licensee: nil, address: nil, start_date: nil, end_date: nil, agreement_period: nil }
  content = scenario[:text]
  
  # Primary extraction patterns (simplified for test)
  licensor_pattern = /licensor\s*:\s*([^:]+?)(?=\s*licensee\s*:|address\s*:|$)/im
  if match = content.match(licensor_pattern)
    name = match[1].strip.gsub(/\s+/, ' ')
    extracted[:licensor] = name unless name.empty?
  end
  
  licensee_pattern = /licensee\s*:\s*([^:]+?)(?=\s*(?:licensor\s*:|address\s*:|$))/im
  if match = content.match(licensee_pattern)
    name = match[1].strip.gsub(/\s+/, ' ')
    extracted[:licensee] = name unless name.empty?
  end
  
  # Fallback extraction if primary failed
  if extracted[:licensor].blank?
    licensor_fallback_patterns = [
      /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][A-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensor)/i,
      /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z]+\s+[A-Z]+(?:\s+[A-Z]+)?)/
    ]
    
    licensor_fallback_patterns.each do |pattern|
      if match = content.match(pattern)
        name = (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
        unless name.empty? || name.length < 3 || name.match?(/^(flat|building|road|address|property)/i)
          extracted[:licensor] = name
          break
        end
      end
    end
  end
  
  if extracted[:licensee].blank?
    licensee_fallback_patterns = [
      /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensee)/i,
      /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z]+\s+[A-Z][a-zA-Z]+)/
    ]
    
    licensee_fallback_patterns.each do |pattern|
      if match = content.match(pattern)
        name = (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
        unless name.empty? || name.length < 3 || name.match?(/^(flat|building|road|address|property)/i)
          extracted[:licensee] = name
          break
        end
      end
    end
  end
  
  puts "  Licensor (cleanup): #{extracted[:licensor].inspect}"
  puts "  Licensee (cleanup): #{extracted[:licensee].inspect}"
  
  puts "\n" + "=" * 60
end

puts "\nTesting complete!"
