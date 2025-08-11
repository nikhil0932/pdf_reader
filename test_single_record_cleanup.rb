#!/usr/bin/env ruby

# Test cleanup on a single record first
require_relative 'config/environment'

# Find a record with blank licensor/licensee
record = PdfDocument.find(85)

puts "Testing cleanup on record ID: #{record.id}"
puts "Filename: #{record.filename}"
puts "Current Licensor: '#{record.licensor}'"
puts "Current Licensee: '#{record.licensee}'"
puts ""

# Apply the enhanced extraction
content = record.content

# Primary patterns (these would normally run first but likely fail for this format)
extracted = {}
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

puts "Primary extraction results:"
puts "  Licensor: '#{extracted[:licensor]}'"
puts "  Licensee: '#{extracted[:licensee]}'"
puts ""

# Fallback extraction if licensor or licensee are empty
if (extracted[:licensor].nil? || extracted[:licensor].empty?) || (extracted[:licensee].nil? || extracted[:licensee].empty?)
  puts "Applying fallback extraction..."
  
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
        puts "  Licensor found via fallback: '#{name}'"
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
        puts "  Licensee found via fallback: '#{name}'"
      end
    end
  end
end

puts ""
puts "Final extraction results:"
puts "  Licensor: '#{extracted[:licensor]}'"
puts "  Licensee: '#{extracted[:licensee]}'"
puts ""

# Apply the service extraction for comparison
puts "PdfDataExtractorService results:"
service = PdfDataExtractorService.new(content)
service_data = service.extract_all_data
puts "  Licensor: '#{service_data[:licensor]}'"
puts "  Licensee: '#{service_data[:licensee]}'"
