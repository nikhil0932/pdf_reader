#!/usr/bin/env ruby

require_relative 'config/environment'

# Test content with SCHEDULE I format
test_content = <<~CONTENT
  LEAVE AND LICENSE AGREEMENT

  SCHEDULE I
  (Being the correct description of premise Apartment/Flat which is the subject matter of these
  presents)
  All that constructed portion being Residential unit bearing Apartment/Flat No. A 607, Built-up
  :57.68 Square Meter, situated on the Floor of a Building known as 'Shine Square' standing on the
  plot of land bearing GAT NUMBER :1193,Road: Newale Wasti, Location: Chikhali Pune 411062, of
  Village:Chikhali,situated within the revenue limits of Tehsil Haveli and Dist Pune and situated within
  the limits of Pimpari-Chinchavad Municipal Corporation.
  IN WITNESS WHEREOF the parties hereto have set and subscribed their respective signatures by
  way of putting thumb impression electronic signature hereto in the presence of witness, who are
  identifying the executants, on the day, month and year first above written.
CONTENT

puts "Testing SCHEDULE I address extraction..."
puts "=" * 50

# Test with PdfDataExtractorService
service = PdfDataExtractorService.new(test_content)
extracted_data = service.extract_all_data

puts "PdfDataExtractorService Results:"
puts "Address: #{extracted_data[:address]}"
puts

# Test manual pattern matching for debugging
puts "Manual Pattern Testing:"
puts "-" * 30

# Test the SCHEDULE I pattern
schedule_pattern = /SCHEDULE\s+I.*?All\s+that\s+constructed\s+portion\s+being.*?(?=IN\s+WITNESS\s+WHEREOF|$)/im
schedule_match = test_content.match(schedule_pattern)

if schedule_match
  puts "SCHEDULE I section found:"
  puts schedule_match[0][0..200] + "..."
  puts
  
  # Extract the property description
  property_desc_pattern = /All\s+that\s+constructed\s+portion\s+being\s+(.+?)(?=IN\s+WITNESS\s+WHEREOF|$)/im
  desc_match = schedule_match[0].match(property_desc_pattern)
  
  if desc_match
    puts "Property Description extracted:"
    puts desc_match[1].strip.gsub(/\s+/, ' ')
  else
    puts "Property description pattern not matched"
  end
else
  puts "SCHEDULE I pattern not matched"
end

puts ""
puts "Expected Address:"
puts "Residential unit bearing Apartment/Flat No. A 607, Built-up :57.68 Square Meter, situated on the Floor of a Building known as 'Shine Square' standing on the plot of land bearing GAT NUMBER :1193,Road: Newale Wasti, Location: Chikhali Pune 411062, of Village:Chikhali,situated within the revenue limits of Tehsil Haveli and Dist Pune and situated within the limits of Pimpari-Chinchavad Municipal Corporation."
