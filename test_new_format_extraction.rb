#!/usr/bin/env ruby

# Test the enhanced extraction logic for the new format
require_relative 'config/environment'

# Sample content in the new format
sample_content = <<~TEXT
LEAVE AND LICENSE AGREEMENT
This agreement is made and executed on 08/06/2023 at Kasarsai
Between,
1) Name: Mr. Kirve Dnyaneshwar Pandurang , Age : About 71 Years, PAN:
CJPPK4296L , Aadhaar: Residing at: Block Sector:Kasarsai , Road:At Post
Kasarsai Tq Mulshi , Pune, Pune, Maharashtra, 410506
HEREINAFTER called 'the Licensor (which expression shall mean and include the
Licensor above named and also his/her/their respective heirs, successors, assigns,
executors and administrators)
AND
1) Name: Mrs./Shrimati/Miss. Mrs Kalaskar Vaheeda Prakash , Age : About
44 Years, PAN: AMMPM7658J , Aadhaar: , Email-id:
vahidakalskar@gmail.com Residing at: Flat No:C-903, Floor No:9th, Building
Name:Opus -77, Block Sector:Near New Poona Bakery Wakad, Road:Vinod Wasti
Marunji Road, Pune, Pune, Maharashtra, 411057
HEREINAFTER called 'the Licensee' (which expression shall mean and include only
Licensee above named).
TEXT

# Create a temporary method to test the extraction logic
def test_clean_extract_data(content)
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
      
      [pattern1, pattern2, pattern3].each_with_index do |pattern, index|
        if match = content.match(pattern)
          puts "Licensor Pattern #{index + 1} matched: #{match[0].truncate(100)}"
          name = if match.captures.length >= 2
            (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
          else
            match[1].to_s.strip.gsub(/\s+/, ' ')
          end
          
          # Clean up the name - remove extra prefixes and normalize
          name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                    .gsub(/\s+/, ' ')
                    .strip
          
          puts "Extracted licensor name: '#{name}'"
          
          # Validation for the extracted name
          if name.present? && 
             name.length >= 5 && 
             name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z]/i) &&
             !name.include?('HEREINAFTER')
            extracted[:licensor] = name
            puts "✅ Licensor validated and accepted: '#{name}'"
            break
          else
            puts "❌ Licensor validation failed"
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
      
      [pattern1, pattern2, pattern3].each_with_index do |pattern, index|
        if match = content.match(pattern)
          puts "Licensee Pattern #{index + 1} matched: #{match[0].truncate(100)}"
          name = if match.captures.length >= 2
            (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
          else
            match[1].to_s.strip.gsub(/\s+/, ' ')
          end
          
          # Clean up the name - remove extra prefixes and normalize
          name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                    .gsub(/\s+/, ' ')
                    .strip
          
          puts "Extracted licensee name: '#{name}'"
          
          # Validation for the extracted name
          if name.present? && 
             name.length >= 5 && 
             name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z]/i) &&
             !name.include?('HEREINAFTER')
            extracted[:licensee] = name
            puts "✅ Licensee validated and accepted: '#{name}'"
            break
          else
            puts "❌ Licensee validation failed"
          end
        end
      end
    end
  end
  
  extracted
end

puts "Testing Enhanced Extraction Logic for New Format"
puts "=" * 50
puts

result = test_clean_extract_data(sample_content)

puts "Final Results:"
puts "Licensor: '#{result[:licensor]}'"
puts "Licensee: '#{result[:licensee]}'"

puts
puts "Expected Results:"
puts "Licensor: 'Mr. Kirve Dnyaneshwar Pandurang'"
puts "Licensee: 'Mrs. Kalaskar Vaheeda Prakash'"

puts
if result[:licensor] == "Mr. Kirve Dnyaneshwar Pandurang" && 
   result[:licensee] == "Mrs. Kalaskar Vaheeda Prakash"
  puts "✅ SUCCESS: Extraction worked correctly for the new format!"
else
  puts "❌ FAILURE: Extraction needs adjustment"
end
