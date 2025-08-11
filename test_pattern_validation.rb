#!/usr/bin/env ruby

# Simple test without Rails dependencies
sample_text = %{KNOW ALL MEN BY THESE PRESENTS that Mr.GADKARI SANDEEP SATISH (hereinafter called "the Licensor") And Mr.Singh Shubham (hereinafter called "the Licensee")}

puts "Testing simple pattern matching..."
puts "Text: #{sample_text}"

# Test the specific fallback pattern for licensor
licensor_pattern = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][A-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensor)/i
if match = sample_text.match(licensor_pattern)
  name = (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
  puts "Licensor match: '#{name}'"
  
  # Test validation
  valid = !name.empty? && 
          name.length >= 8 && 
          name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s+[A-Z][a-zA-Z]{2,}/i) &&
          name.count(' ') >= 2 &&
          name.split(' ').all? { |word| word.length >= 2 }
  
  puts "Valid: #{valid}"
end

# Test the specific fallback pattern for licensee
licensee_pattern = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensee)/i
if match = sample_text.match(licensee_pattern)
  name = (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
  puts "Licensee match: '#{name}'"
  
  # Test validation
  valid = !name.empty? && 
          name.length >= 8 && 
          name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s+[A-Z][a-zA-Z]{2,}/i) &&
          name.count(' ') >= 2 &&
          name.split(' ').all? { |word| word.length >= 2 }
  
  puts "Valid: #{valid}"
end

puts "\nTesting edge case..."
edge_text = "Some document without clear licensor or licensee information"
puts "Text: #{edge_text}"

# Test patterns don't match edge case
if match = edge_text.match(licensor_pattern)
  puts "ERROR: Licensor pattern matched edge case: '#{match[0]}'"
else
  puts "✓ Licensor pattern correctly ignored edge case"
end

if match = edge_text.match(licensee_pattern)
  puts "ERROR: Licensee pattern matched edge case: '#{match[0]}'"
else
  puts "✓ Licensee pattern correctly ignored edge case"
end
