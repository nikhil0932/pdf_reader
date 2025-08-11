#!/usr/bin/env ruby

# Test script for the problematic Mrs./Shrimati/Miss. format
# This tests the specific case where we get "Mrs. Mrs Kalaskar Vaheeda Prakash"

# Test content with the problematic format
test_content = <<~CONTENT
  LEAVE AND LICENSE AGREEMENT
  
  THIS AGREEMENT is entered into today for and on behalf of 
  1) Name: Mr. Sharma Rajesh Kumar, Age: 45 Years, Address: Shop no. 1, 2, 3 & 4, Adani CNG Pump, Pimple Saudagar, Pune - 411027. HEREINAFTER called 'the Licensor' (which expression shall mean and include his heirs, executors, administrators, successors and assigns) of the ONE PART  
  
  AND
  
  1) Name: Mrs./Shrimati/Miss. Mrs Kalaskar Vaheeda Prakash, Age: 35 Years, Address: 123 Main Street, City Center, Mumbai - 400001. HEREINAFTER called 'the Licensee' (which expression shall mean and include his heirs, executors, administrators, successors and assigns) of the OTHER PART.
  
  WHEREAS the Licensor is the absolute owner of the property...
CONTENT

puts "Testing Mrs./Shrimati/Miss. format extraction..."
puts "=" * 50

# Test with current rake task logic
def clean_extract_data(content)
  extracted = { licensor: nil, licensee: nil, address: nil, start_date: nil, end_date: nil, agreement_period: nil }
  
  # Extract Licensor name (before "Address:")
  licensor_pattern = /Licensor\s*\n?\s*([^A-Z]*?)(?:Address:|Licensee)/mi
  if match = content.match(licensor_pattern)
    name = match[1].strip.gsub(/\s+/, ' ')
    # Clean up common prefixes and get just the name
    name = name.gsub(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*/i, '\1 ').strip
    extracted[:licensor] = name unless name.empty?
  end

  # Extract Licensee name (before "Address:")  
  licensee_pattern = /Licensee\s*\n?\s*([^A-Z]*?)(?:Address:|All that)/mi
  if match = content.match(licensee_pattern)
    name = match[1].strip.gsub(/\s+/, ' ')
    # Clean up common prefixes and get just the name
    name = name.gsub(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*/i, '\1 ').strip
    extracted[:licensee] = name unless name.empty?
  end

  # Enhanced fallback extraction if licensor or licensee are empty
  if extracted[:licensor].blank? || extracted[:licensee].blank?
    # Fallback patterns for licensor
    if extracted[:licensor].blank?
      # Pattern 1: Most specific pattern for "called 'the Licensor'"
      pattern1 = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][A-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensor)/i
      
      # Pattern 2: Extract from "Name:" field in structured format (first occurrence before "HEREINAFTER called 'the Licensor'")
      pattern2 = /Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensor)/im
      
      # Pattern 3: Enhanced pattern for the new format - extract name after "Name:" and before comma/Age
      pattern3 = /1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
      
      [pattern1, pattern2, pattern3].each do |pattern|
        if match = content.match(pattern)
          name = if match.captures.length >= 2
            (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
          else
            match[1].to_s.strip.gsub(/\s+/, ' ')
          end
          
          # Clean up the name - remove extra prefixes and normalize
          name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                    .gsub(/\s+/, ' ')
                    .strip
          
          # Validation for the extracted name
          if name.present? && 
             name.length >= 5 && 
             name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z]/i) &&
             !name.include?('HEREINAFTER')
            extracted[:licensor] = name
            break
          end
        end
      end
    end
    
    # Fallback patterns for licensee  
    if extracted[:licensee].blank?
      # Pattern 1: Most specific pattern for "called 'the Licensee'"
      pattern1 = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensee)/i
      
      # Pattern 2: Extract second "Name:" field (for licensee in structured format)
      # Look for Name: after finding first licensor section
      pattern2 = /HEREINAFTER.*?called.*?Licensor.*?AND.*?Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensee)/im
      
      # Pattern 3: Enhanced pattern for the new format - find second "1) Name:" after "AND"
      pattern3 = /AND\s+1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
      
      [pattern1, pattern2, pattern3].each do |pattern|
        if match = content.match(pattern)
          name = if match.captures.length >= 2
            (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
          else
            match[1].to_s.strip.gsub(/\s+/, ' ')
          end
          
          # Clean up the name - remove extra prefixes and normalize
          name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                    .gsub(/\s+/, ' ')
                    .strip
          
          # Validation for the extracted name
          if name.present? && 
             name.length >= 5 && 
             name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z]/i) &&
             !name.include?('HEREINAFTER')
            extracted[:licensee] = name
            break
          end
        end
      end
    end
  end
  
  extracted
end

puts "Current Rake Task clean_extract_data Results:"
rake_results = clean_extract_data(test_content)
puts "Licensor: #{rake_results[:licensor]}"
puts "Licensee: #{rake_results[:licensee]}"
puts

# Test individual pattern matches for debugging
puts "Pattern Debug Information:"
puts "-" * 30

# Test licensor pattern
licensor_pattern3 = /1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
if match = test_content.match(licensor_pattern3)
  puts "Licensor Pattern 3 Match: '#{match[1]}'"
  # Show the cleaning process
  name = match[1].to_s.strip.gsub(/\s+/, ' ')
  puts "After initial cleanup: '#{name}'"
  name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
  puts "After Mrs./Shrimati/Miss. replacement: '#{name}'"
  name = name.gsub(/\s+/, ' ').strip
  puts "Final cleaned name: '#{name}'"
else
  puts "Licensor Pattern 3: No match"
end

puts

# Test licensee pattern
licensee_pattern3 = /AND\s+1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
if match = test_content.match(licensee_pattern3)
  puts "Licensee Pattern 3 Match: '#{match[1]}'"
  # Show the cleaning process
  name = match[1].to_s.strip.gsub(/\s+/, ' ')
  puts "After initial cleanup: '#{name}'"
  name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
  puts "After Mrs./Shrimati/Miss. replacement: '#{name}'"
  name = name.gsub(/\s+/, ' ').strip
  puts "Final cleaned name: '#{name}'"
else
  puts "Licensee Pattern 3: No match"
end

puts "\nExpected Results:"
puts "Licensor: Mr. Sharma Rajesh Kumar"
puts "Licensee: Mrs. Kalaskar Vaheeda Prakash"  # NOT "Mrs. Mrs Kalaskar Vaheeda Prakash"
