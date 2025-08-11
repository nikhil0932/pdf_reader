#!/usr/bin/env ruby

require_relative 'config/environment'

# Test the task logic on a single record
record = PdfDocument.find(85)

puts "Testing enhanced extraction on record ID: #{record.id}"
puts "Filename: #{record.filename}"
puts "Current Licensor: '#{record.licensor}'"
puts "Current Licensee: '#{record.licensee}'"
puts ""

def clean_extract_data(content)
  extracted = { licensor: nil, licensee: nil }
  
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
      # Pattern 2: Extract from "Name:" field in structured format  
      pattern2 = /Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensor)/im
      
      if match = content.match(pattern2)
        name = match[1].to_s.strip.gsub(/\s+/, ' ')
        
        # Strict validation for the extracted name
        if !name.empty? && 
           name.length >= 8 && 
           name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z]{2,}/i) &&
           name.count(' ') >= 1 &&  # Title + name minimum
           name.split(' ').all? { |word| word.length >= 2 }
          extracted[:licensor] = name
        end
      end
    end
    
    # Fallback patterns for licensee  
    if extracted[:licensee].nil? || extracted[:licensee].empty?
      # Pattern 2: Extract second "Name:" field (for licensee in structured format)
      pattern2 = /HEREINAFTER.*?called.*?Licensor.*?AND.*?Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensee)/im
      
      if match = content.match(pattern2)
        name = match[1].to_s.strip.gsub(/\s+/, ' ')
        
        # Strict validation for the extracted name
        if !name.empty? && 
           name.length >= 8 && 
           name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z]{2,}/i) &&
           name.count(' ') >= 1 &&  # Title + name minimum
           name.split(' ').all? { |word| word.length >= 2 }
          extracted[:licensee] = name
        end
      end
    end
  end
  
  extracted
end

# Test extraction
extracted_data = clean_extract_data(record.content)

puts "Extracted data:"
puts "  Licensor: '#{extracted_data[:licensor]}'"
puts "  Licensee: '#{extracted_data[:licensee]}'"

# Actually update the record
if (record.licensor.blank? && extracted_data[:licensor].present?) || 
   (record.licensee.blank? && extracted_data[:licensee].present?)
  
  puts ""
  puts "Updating record..."
  
  record.licensor = extracted_data[:licensor] if record.licensor.blank? && extracted_data[:licensor].present?
  record.licensee = extracted_data[:licensee] if record.licensee.blank? && extracted_data[:licensee].present?
  
  if record.save
    puts "✅ Record updated successfully!"
    puts "  New Licensor: '#{record.licensor}'"
    puts "  New Licensee: '#{record.licensee}'"
  else
    puts "❌ Failed to save record: #{record.errors.full_messages.join(', ')}"
  end
else
  puts ""
  puts "ℹ️  No updates needed (no improvement found)"
end
