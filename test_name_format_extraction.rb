#!/usr/bin/env ruby

# Test script for Name: format extraction
# This tests the enhanced fallback extraction for licensor/licensee names in "Name:" format

# Test content similar to the format you described
test_content = <<~CONTENT
  LEAVE AND LICENSE AGREEMENT
  
  THIS AGREEMENT is entered into today for and on behalf of 
  Name: Mr.Dhamale Devram Vishwasrao, Age: 35 Years, Address: Shop no. 1, 2, 3 & 4, Adani CNG Pump, Pimple Saudagar, Pune - 411027. HEREINAFTER called 'the Licensor' (which expression shall mean and include his heirs, executors, administrators, successors and assigns) of the ONE PART  
  
  AND
  
  Name: Mr.Reddy Arulraj, Age: 30 Years, Address: 123 Main Street, City Center, Mumbai - 400001. HEREINAFTER called 'the Licensee' (which expression shall mean and include his heirs, executors, administrators, successors and assigns) of the OTHER PART.
  
  WHEREAS the Licensor is the absolute owner of the property...
CONTENT

puts "Testing Name: format extraction..."
puts "=" * 50

# Test with PdfDataExtractorService
require_relative 'config/environment'

service = PdfDataExtractorService.new(test_content)
extracted_data = service.extract_all_data

puts "PdfDataExtractorService Results:"
puts "Licensor: #{extracted_data[:licensor]}"
puts "Licensee: #{extracted_data[:licensee]}"
puts

def clean_extract_data(content)
  extracted = {}
  
  # Primary patterns (these would normally run first but likely fail for this format)
  licensor_pattern = /Licensor\s*\n?\s*([^A-Z]*?)(?:Address:|All that)/mi
  if match = content.match(licensor_pattern)
    name = match[1].strip.gsub(/\s+/, ' ')
    name = name.gsub(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*/i, '\1 ').strip
    extracted[:licensor] = name unless name.empty?
  end

  licensee_pattern = /Licensee\s*\n?\s*([^A-Z]*?)(?:Address:|All that)/mi
  if match = content.match(licensee_pattern)
    name = match[1].strip.gsub(/\s+/, ' ')
    name = name.gsub(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*/i, '\1 ').strip
    extracted[:licensee] = name unless name.empty?
  end
  
  # Fallback extraction if licensor or licensee are empty
  if (extracted[:licensor].nil? || extracted[:licensor].empty?) || (extracted[:licensee].nil? || extracted[:licensee].empty?)
    # Fallback patterns for licensor
    if extracted[:licensor].nil? || extracted[:licensor].empty?
      # Pattern 1: Most specific pattern for "called 'the Licensor'"
      pattern1 = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][A-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensor)/i
      
      # Pattern 2: Extract from "Name:" field in structured format  
      pattern2 = /Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensor)/im
      
      [pattern1, pattern2].each do |pattern|
        if match = content.match(pattern)
          name = if match.captures.length >= 2
            (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
          else
            match[1].to_s.strip.gsub(/\s+/, ' ')
          end
          
          # Strict validation for the extracted name
          if !name.empty? && 
             name.length >= 8 && 
             name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z]{2,}/i) &&
             name.count(' ') >= 1 &&  # Title + name minimum
             name.split(' ').all? { |word| word.length >= 2 }
            extracted[:licensor] = name
            break
          end
        end
      end
    end
    
    # Fallback patterns for licensee  
    if extracted[:licensee].nil? || extracted[:licensee].empty?
      # Pattern 1: Most specific pattern for "called 'the Licensee'"
      pattern1 = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensee)/i
      
      # Pattern 2: Extract second "Name:" field (for licensee in structured format)
      # Look for Name: after finding first licensor section
      pattern2 = /HEREINAFTER.*?called.*?Licensor.*?AND.*?Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensee)/im
      
      [pattern1, pattern2].each do |pattern|
        if match = content.match(pattern)
          name = if match.captures.length >= 2
            (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
          else
            match[1].to_s.strip.gsub(/\s+/, ' ')
          end
          
          # Strict validation for the extracted name
          if !name.empty? && 
             name.length >= 8 && 
             name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z]{2,}/i) &&
             name.count(' ') >= 1 &&  # Title + name minimum
             name.split(' ').all? { |word| word.length >= 2 }
            extracted[:licensee] = name
            break
          end
        end
      end
    end
  end
  
  extracted
end

puts "Rake Task clean_extract_data Results:"
rake_results = clean_extract_data(test_content)
puts "Licensor: #{rake_results[:licensor]}"
puts "Licensee: #{rake_results[:licensee]}"
puts

# Test individual pattern matches for debugging
puts "Pattern Debug Information:"
puts "-" * 30

# Test licensor pattern
licensor_pattern = /Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensor)/im
if match = test_content.match(licensor_pattern)
  puts "Licensor Pattern Match: '#{match[1]}'"
else
  puts "Licensor Pattern: No match"
end

# Test licensee pattern
licensee_pattern = /HEREINAFTER.*?called.*?Licensor.*?AND.*?Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensee)/im
if match = test_content.match(licensee_pattern)
  puts "Licensee Pattern Match: '#{match[1]}'"
else
  puts "Licensee Pattern: No match"
end

puts "\nExpected Results:"
puts "Licensor: Mr.Dhamale Devram Vishwasrao"
puts "Licensee: Mr.Reddy Arulraj"
