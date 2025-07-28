class PdfDataExtractorService
  def initialize(content)
    @content = content
  end

  def extract_all_data
    return {} if @content.blank? || @content.include?("Error processing PDF")
    
    {
      licensor: extract_licensor,
      licensee: extract_licensee,
      address: extract_address,
      agreement_date: extract_agreement_date,
      agreement_period: extract_agreement_period,
      filtered_data: compile_filtered_data
    }
  end

  private

  def extract_licensor
    # Try specific patterns for the document format
    patterns = [
      # Pattern for "Licensor:" followed by multi-line content
      /licensor\s*:\s*([^:]+?)(?=\s*licensee\s*:|address\s*:|$)/im,
      # Pattern for "Licensor" without colon
      /licensor\s*\n\s*([^:]+?)(?=\s*\n\s*(?:licensee|address|tenant|owner))/im,
      # Pattern for licensor with address structure
      /licensor\s*:?\s*([^:]+?)(?=\s*(?:flat|building|address:|licensee:))/im,
      # Original patterns
      /licensor[:\s]+([^\n\r]+)/i,
      /owner[:\s]+([^\n\r]+)/i,
      /landlord[:\s]+([^\n\r]+)/i,
      /lessor[:\s]+([^\n\r]+)/i
    ]
    
    result = extract_by_patterns(patterns)
    
    # Clean up the extracted text
    if result
      result = clean_extracted_text(result)
      # Remove common address indicators from licensor name
      result = result.gsub(/\s*(?:flat no\.?|building|road|sector|district|state|pin|pincode).*$/i, '').strip
    end
    
    result
  end

  def extract_licensee
    # Try specific patterns for the document format
    patterns = [
      # Pattern for "Licensee:" followed by multi-line content
      /licensee\s*:\s*([^:]+?)(?=\s*(?:licensor\s*:|address\s*:|$))/im,
      # Pattern for "Licensee" without colon
      /licensee\s*\n\s*([^:]+?)(?=\s*\n\s*(?:licensor|address|owner))/im,
      # Pattern for licensee with address structure
      /licensee\s*:?\s*([^:]+?)(?=\s*(?:flat|building|address:|licensor:))/im,
      # Original patterns
      /licensee[:\s]+([^\n\r]+)/i,
      /tenant[:\s]+([^\n\r]+)/i,
      /lessee[:\s]+([^\n\r]+)/i,
      /occupant[:\s]+([^\n\r]+)/i
    ]
    
    result = extract_by_patterns(patterns)
    
    # Clean up the extracted text
    if result
      result = clean_extracted_text(result)
      # Remove common address indicators from licensee name
      result = result.gsub(/\s*(?:flat no\.?|building|road|sector|district|state|pin|pincode).*$/i, '').strip
    end
    
    result
  end

  def extract_address
    # First try to extract from "Property Details:" section
    property_details_match = @content.match(/property\s+details\s*:\s*([^:]+?)(?=\s*(?:licens[eo]r|agreement|date|period|$))/im)
    
    if property_details_match
      address = parse_structured_address(property_details_match[1])
      return address if address.present?
    end
    
    # Fallback to other patterns
    patterns = [
      # Pattern for complete address after "Address:" (multi-line)
      /address\s*:\s*([^:]+?)(?=\s*(?:licens[eo]r|tenant|owner|agreement|period|$))/im,
      # Pattern for property address starting with specific markers
      /(?:property\s+address|premises\s+address|situated\s+at|located\s+at)\s*:?\s*([^:]+?)(?=\s*(?:licens[eo]r|tenant|owner|agreement|period|$))/im,
      # Pattern for address after flat/building details
      /(?:flat no\.?|building|road|sector)[^:]*([^:]+?)(?=\s*(?:licens[eo]r|tenant|owner|agreement|period|$))/im,
      # Original patterns with improved boundaries
      /(?:property\s+)?address[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i,
      /(?:situated\s+at|located\s+at)[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i,
      /premises[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i,
      /property[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i
    ]
    
    address = extract_by_patterns(patterns)
    
    # If no address found, try to extract from the entire content
    if address.blank?
      # Look for address patterns in the full content
      address_patterns = [
        # Complete address with common components
        /((?:flat no\.?|building|road|sector)[^:]*(?:district|state|pin|pincode)[^:]*)/im,
        # Address with PIN code
        /(\d+[^\n\r]*(?:pin|pincode)\s*[:\-]?\s*\d{6}[^\n\r]*)/i,
        # Street/road address
        /(\d+[^\n\r]*(?:street|road|avenue|lane|block|sector)[^\n\r]*)/i
      ]
      
      address_patterns.each do |pattern|
        match = @content.match(pattern)
        if match && match[1]
          address = match[1].strip
          break
        end
      end
    end
    
    # Clean up the address
    if address
      address = clean_extracted_text(address)
      address = format_address(address)
    end
    
    address
  end

  def extract_agreement_date
    patterns = [
      # Pattern for dates in the document
      /(?:agreement\s+)?date[:\s]+(\d{1,2}[-\/\.]\d{1,2}[-\/\.]\d{2,4})/i,
      /(?:executed\s+on|signed\s+on|dated)[:\s]+(\d{1,2}[-\/\.]\d{1,2}[-\/\.]\d{2,4})/i,
      /this\s+(\d{1,2})\w*\s+day\s+of\s+(\w+)[,\s]+(\d{2,4})/i,
      # Pattern for dates with months
      /(\d{1,2})\w*\s+(january|february|march|april|may|june|july|august|september|october|november|december)[,\s]+(\d{2,4})/i,
      # Pattern for any date format
      /(\d{1,2}[-\/\.]\d{1,2}[-\/\.]\d{2,4})/
    ]
    
    # Try standard date patterns first
    patterns.each do |pattern|
      match = @content.match(pattern)
      if match
        date_str = if match.captures.length == 1
          match[1]
        elsif match.captures.length == 3
          "#{match[1]} #{match[2]} #{match[3]}"
        else
          match[0]
        end
        
        begin
          parsed_date = Date.parse(date_str)
          # Only return dates that seem reasonable (not too old or too far in future)
          if parsed_date.year >= 1990 && parsed_date.year <= Date.current.year + 10
            return parsed_date
          end
        rescue Date::Error
          next
        end
      end
    end
    
    nil
  end

  def extract_agreement_period
    patterns = [
      # Enhanced patterns for period/duration
      /(?:period|duration|term)[:\s]+([^\n\r]+?)(?=\s*(?:licens[eo]r|tenant|owner|agreement|$))/im,
      /for\s+a\s+(?:period\s+of\s+)?([^\n\r]+?)(?=\s*(?:licens[eo]r|tenant|owner|agreement|$))/im,
      /(\d+\s+(?:months?|years?|days?))/i,
      /(?:commencing\s+from|starting\s+from)[:\s]+([^\n\r]+)/i,
      /(?:valid\s+for|effective\s+for)[:\s]+([^\n\r]+)/i,
      # Pattern for rental period
      /rental\s+period[:\s]+([^\n\r]+)/i,
      /lease\s+term[:\s]+([^\n\r]+)/i
    ]
    
    result = extract_by_patterns(patterns)
    
    # Clean up the result
    if result
      result = clean_extracted_text(result)
      # Remove common artifacts
      result = result.gsub(/^(from|to|starting|commencing)\s+/i, '').strip
    end
    
    result
  end

  def extract_by_patterns(patterns)
    patterns.each do |pattern|
      match = @content.match(pattern)
      if match && match[1]
        result = match[1].strip
        # Clean up common artifacts
        result = result.gsub(/[:\-_]+$/, '').strip
        result = result.gsub(/^\s*\n/, '').gsub(/\n\s*$/, '').strip
        return result if result.present?
      end
    end
    nil
  end

  # Helper method to clean extracted text
  def clean_extracted_text(text)
    return nil if text.blank?
    
    # Replace multiple newlines and spaces with single space
    text = text.gsub(/\n+/, ' ').strip
    text = text.gsub(/\s+/, ' ')
    
    # Clean up common prefixes and suffixes
    text = text.gsub(/^(mr\.|mrs\.|ms\.|dr\.)\s*/i, '\1 ')
    text = text.gsub(/[:\-_]+$/, '').strip
    
    # Remove empty lines and trim
    text = text.gsub(/^\s*\n/, '').gsub(/\n\s*$/, '').strip
    
    text.present? ? text : nil
  end

  # Method to extract specific data between two markers
  def extract_between_markers(start_marker, end_marker)
    pattern = /#{Regexp.escape(start_marker)}\s*\n\s*(.*?)(?=\s*\n\s*#{Regexp.escape(end_marker)})/im
    match = @content.match(pattern)
    if match && match[1]
      result = match[1].strip
      result = result.gsub(/\n+/, ' ').gsub(/\s+/, ' ').strip
      return result if result.present?
    end
    nil
  end

  def compile_filtered_data
    data = {
      "Licensor" => extract_licensor,
      "Licensee" => extract_licensee,
      "Address" => extract_address,
      "Agreement Date" => extract_agreement_date&.strftime("%B %d, %Y"),
      "Agreement Period" => extract_agreement_period
    }
    
    # Only include non-blank values
    filtered = data.select { |_, v| v.present? }
    
    return nil if filtered.empty?
    
    filtered.map { |k, v| "#{k}: #{v}" }.join("\n")
  end

  # Parse structured address from "Property Details:" format
  # Example: "Apartment/Flat No:-, Floor No:-, Building Name:/Pandurang Nagar , Block Sector:Pune-411014, Road:Pune City, City:Yevalewadi, District:Pune"
  def parse_structured_address(address_text)
    return nil if address_text.blank?
    
    # Clean the text first
    text = address_text.strip.gsub(/\s+/, ' ')
    
    # Extract components using regex patterns
    components = {}
    
    # Extract flat/apartment number
    flat_match = text.match(/(?:apartment|flat)\s+no\s*:?\s*([^,]+)/i)
    components['flat'] = flat_match[1].strip if flat_match && flat_match[1].strip != '-'
    
    # Extract floor number
    floor_match = text.match(/floor\s+no\s*:?\s*([^,]+)/i)
    components['floor'] = floor_match[1].strip if floor_match && floor_match[1].strip != '-'
    
    # Extract building name
    building_match = text.match(/building\s+name\s*:?\s*\/?\s*([^,]+)/i)
    components['building'] = building_match[1].strip if building_match && !building_match[1].strip.empty?
    
    # Extract block/sector
    block_match = text.match(/(?:block\s+)?sector\s*:?\s*([^,]+)/i)
    components['sector'] = block_match[1].strip if block_match
    
    # Extract road
    road_match = text.match(/road\s*:?\s*([^,]+)/i)
    components['road'] = road_match[1].strip if road_match
    
    # Extract city
    city_match = text.match(/city\s*:?\s*([^,]+)/i)
    components['city'] = city_match[1].strip if city_match
    
    # Extract district
    district_match = text.match(/district\s*:?\s*([^,]+)/i)
    components['district'] = district_match[1].strip if district_match
    
    # Extract PIN code
    pin_match = text.match(/(\d{6})/i)
    components['pin'] = pin_match[1] if pin_match
    
    # Build formatted address
    address_parts = []
    
    if components['flat'].present?
      address_parts << "Flat #{components['flat']}"
    end
    
    if components['floor'].present?
      address_parts << "Floor #{components['floor']}"
    end
    
    if components['building'].present?
      address_parts << components['building']
    end
    
    if components['sector'].present?
      address_parts << components['sector']
    end
    
    if components['road'].present?
      address_parts << components['road']
    end
    
    if components['city'].present?
      address_parts << components['city']
    end
    
    if components['district'].present?
      address_parts << components['district']
    end
    
    if components['pin'].present?
      address_parts << "PIN #{components['pin']}"
    end
    
    # Join with commas
    formatted_address = address_parts.join(', ')
    
    return formatted_address.present? ? formatted_address : nil
  end

  # Format address by cleaning common patterns
  def format_address(address)
    return nil if address.blank?
    
    # Remove specific artifacts and clean formatting
    address = address.gsub(/flat no\.?:?\s*/i, 'Flat ')
    address = address.gsub(/building name:?\s*\/?\s*/i, 'Building: ')
    address = address.gsub(/road:?\s*/i, 'Road ')
    address = address.gsub(/sector:?\s*/i, 'Sector ')
    address = address.gsub(/district:?\s*/i, 'District ')
    address = address.gsub(/state:?\s*/i, 'State ')
    address = address.gsub(/pin(?:code)?:?\s*/i, 'PIN ')
    address = address.gsub(/not available/i, '').strip
    
    # Clean up multiple commas and colons
    address = address.gsub(/,\s*,/, ',').gsub(/:\s*,/, ', ').gsub(/,\s*:/, ', ')
    address = address.gsub(/^[,:\s]+|[,:\s]+$/, '').strip
    
    address
  end
end
