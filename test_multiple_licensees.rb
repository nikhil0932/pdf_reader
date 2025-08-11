#!/usr/bin/env ruby

# Test script for multiple licensees format extraction
# This tests the new format where there are multiple licensees listed

# Test content with multiple licensees format
test_content = <<~CONTENT
  LEAVE AND LICENSE AGREEMENT
  
  1) Name: Mr.Choubey Anand , Age : About 32 Years, PAN : BHHPC5109H Residing at: Flat
  No:/110, Floor No:-, Building Name:Kalindi Mid Town , Block Sector:Indore , Road:A B Road By
  Pass Deoguradia , Indore, Indore, Madhya pradesh, 452016
  HEREINAFTER called 'the Licensor (which expression shall mean and include the Licensor above
  named and also his/her/their respective heirs, successors, assigns, executors and administrators)
  AND
  1) Name: Miss Aliza Imtiyazali Rangrez, Age : About 22 Years Residing at: Block Sector:Yeola,
  Road:Theatre Road , Nashik, Nashik, Maharashtra, 423401
  2) Name: Miss Vaishnavi Jaydeep Pangavhane, Age : About 23 Years Residing at: Block
  Sector:Ahmadnagar , Road:Anganwadi Parisar Mahegaon , Ahmednagar, Ahmednagar,
  Maharashtra, 423602
  3) Name: Miss Divya Sanjay Thorat, Age : About 23 Years Residing at: Block Sector:Ahmadnagar
  , Road:Laxmi Nagar Kopargaon , Ahmednagar, Ahmednagar, Maharashtra, 423601
  4) Name: Miss Tanvi Ravindra Aher, Age : About 22 Years Residing at: Block Sector:Ahmadnagar
  , Road:Aher Vasti Chas Chas Nali , Ahmednagar, Ahmednagar, Maharashtra, 423604
  HEREINAFTER called 'the Licensees' (which expression shall mean and include only Licensees
  above named).
  
  WHEREAS the Licensor is the absolute owner of the property...
CONTENT

puts "Testing Multiple Licensees format extraction..."
puts "=" * 50

# Load the clean_extract_data method from the rake file
require_relative 'config/environment'

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
      
      # Pattern 4: Handle multiple licensees format - extract all names after "AND" section
      pattern4 = /HEREINAFTER.*?called.*?Licensor.*?AND(.*?)HEREINAFTER.*?called.*?Licensees/im
      
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
      
      # If still no licensee found, try to extract multiple licensees
      if extracted[:licensee].blank?
        if match = content.match(pattern4)
          licensee_section = match[1]
          # Extract all "Name:" entries from the licensee section
          name_matches = licensee_section.scan(/\d+\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Miss)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im)
          
          if name_matches.any?
            licensee_names = name_matches.map do |name_match|
              name = name_match[0].to_s.strip.gsub(/\s+/, ' ')
              # Clean up the name
              name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                        .gsub(/\s+/, ' ')
                        .strip
              
              # Validate the name
              if name.present? && 
                 name.length >= 5 && 
                 name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.|Miss)\s*[A-Z]/i)
                name
              else
                nil
              end
            end.compact
            
            if licensee_names.any?
              # Join multiple licensees with commas
              extracted[:licensee] = licensee_names.join(', ')
            end
          end
        end
      end
    end
  end
  
  extracted
end

puts "Current enhanced clean_extract_data Results:"
results = clean_extract_data(test_content)
puts "Licensor: #{results[:licensor]}"
puts "Licensee: #{results[:licensee]}"
puts

# Test individual pattern matches for debugging
puts "Pattern Debug Information:"
puts "-" * 30

# Test licensor pattern
licensor_pattern3 = /1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
if match = test_content.match(licensor_pattern3)
  puts "Licensor Pattern 3 Match: '#{match[1]}'"
else
  puts "Licensor Pattern 3: No match"
end

# Test multiple licensees pattern
licensee_pattern4 = /HEREINAFTER.*?called.*?Licensor.*?AND(.*?)HEREINAFTER.*?called.*?Licensees/im
if match = test_content.match(licensee_pattern4)
  puts "Multiple Licensees Section Found:"
  licensee_section = match[1]
  puts "Section content: #{licensee_section.truncate(200)}"
  
  # Extract all names
  name_matches = licensee_section.scan(/\d+\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Miss)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im)
  puts "Found #{name_matches.length} licensee name matches:"
  name_matches.each_with_index do |name_match, index|
    puts "  #{index + 1}. '#{name_match[0]}'"
  end
else
  puts "Multiple Licensees Pattern: No match"
end

puts "\nExpected Results:"
puts "Licensor: Mr.Choubey Anand"
puts "Licensee: Miss Aliza Imtiyazali Rangrez, Miss Vaishnavi Jaydeep Pangavhane, Miss Divya Sanjay Thorat, Miss Tanvi Ravindra Aher"
