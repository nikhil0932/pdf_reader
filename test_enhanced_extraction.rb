#!/usr/bin/env ruby
require_relative 'config/environment'

# Test the enhanced extraction with the new format
sample_text = %{
LEAVE AND LICENSE AGREEMENT
 This agreement is made and executed on 28/10/2021 at Pune
Between,
1) Name: Mr.Dhamale Devram Vishwasrao, Age : About 45 Years, PAN : ANWPD7204N Residing
at: Flat No:Sr. No. 70, Block Sector:Ganesh Nagar, Road:Near Bindu Lab, New Sangavi, Pune,
Maharashtra, 411027
HEREINAFTER called 'the Licensor (which expression shall mean and include the Licensor above
named and also his/her/their respective heirs, successors, assigns, executors and administrators)
AND
1) Name: Mr.Reddy Arulraj , Age : About 31 Years, Occupation : Service Residing at: Flat No:X107/17, Block Sector:Godrej Station Side Colony, Pirojsha Nagar, Road:-, Vikhroli East, Mumbai,
Maharashtra, 400079
HEREINAFTER called 'the Licensee' (which expression shall mean and include only Licensee
above named)
}

puts "Testing enhanced extraction with new format..."
puts "Sample text:"
puts sample_text
puts "\n" + "="*60 + "\n"

service = PdfDataExtractorService.new(sample_text)
extracted_data = service.extract_all_data

puts "Extracted data:"
puts "Licensor: #{extracted_data[:licensor].inspect}"
puts "Licensee: #{extracted_data[:licensee].inspect}"
puts "Address: #{extracted_data[:address].inspect}"
puts "Agreement Date: #{extracted_data[:agreement_date].inspect}"

puts "\n" + "="*60 + "\n"

# Test the patterns manually
puts "Testing individual patterns:"

# Test licensor patterns
licensor_patterns = [
  /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][A-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensor)/i,
  /Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s]+?)(?:,|\s*Age|\s*HEREINAFTER.*Licensor)/i
]

puts "Licensor patterns:"
licensor_patterns.each_with_index do |pattern, index|
  if match = sample_text.match(pattern)
    name = if match.captures.length >= 2
      (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
    else
      match[1].to_s.strip.gsub(/\s+/, ' ')
    end
    puts "  Pattern #{index + 1}: MATCHED - '#{name}'"
    puts "    Full match: '#{match[0]}'"
  else
    puts "  Pattern #{index + 1}: NO MATCH"
  end
end

# Test licensee patterns
licensee_patterns = [
  /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensee)/i,
  /HEREINAFTER.*?Licensor.*?AND.*?Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z][a-zA-Z\s]+?)(?:,|\s*Age|\s*HEREINAFTER.*Licensee)/im
]

puts "\nLicensee patterns:"
licensee_patterns.each_with_index do |pattern, index|
  if match = sample_text.match(pattern)
    name = if match.captures.length >= 2
      (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
    else
      match[1].to_s.strip.gsub(/\s+/, ' ')
    end
    puts "  Pattern #{index + 1}: MATCHED - '#{name}'"
    puts "    Full match: '#{match[0]}'"
  else
    puts "  Pattern #{index + 1}: NO MATCH"
  end
end

puts "\nTesting complete!"
