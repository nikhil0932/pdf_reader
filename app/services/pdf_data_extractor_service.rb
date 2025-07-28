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
    patterns = [
      /licensor[:\s]+([^\n\r]+)/i,
      /owner[:\s]+([^\n\r]+)/i,
      /landlord[:\s]+([^\n\r]+)/i,
      /lessor[:\s]+([^\n\r]+)/i
    ]
    
    extract_by_patterns(patterns)
  end

  def extract_licensee
    patterns = [
      /licensee[:\s]+([^\n\r]+)/i,
      /tenant[:\s]+([^\n\r]+)/i,
      /lessee[:\s]+([^\n\r]+)/i,
      /occupant[:\s]+([^\n\r]+)/i
    ]
    
    extract_by_patterns(patterns)
  end

  def extract_address
    patterns = [
      /(?:property\s+)?address[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i,
      /(?:situated\s+at|located\s+at)[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i,
      /premises[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i,
      /property[:\s]+([^\n\r]+(?:\n[^\n\r]+)*)/i
    ]
    
    address = extract_by_patterns(patterns)
    
    # Try to find a complete address with common address patterns
    if address.blank?
      address_match = @content.match(/(\d+[^\n\r]*(?:street|road|avenue|lane|block|sector|city|district|state|pin|pincode)[^\n\r]*)/i)
      address = address_match[1].strip if address_match
    end
    
    # Clean up the address
    address&.gsub(/\s+/, ' ')&.strip
  end

  def extract_agreement_date
    patterns = [
      /(?:agreement\s+)?date[:\s]+(\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4})/i,
      /(?:executed\s+on|signed\s+on|dated)[:\s]+(\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4})/i,
      /this\s+(\d{1,2})\w*\s+day\s+of\s+(\w+)[,\s]+(\d{2,4})/i
    ]
    
    # Try standard date patterns first
    patterns.each do |pattern|
      match = @content.match(pattern)
      if match
        date_str = if match.captures.length == 1
          match[1]
        else
          "#{match[1]} #{match[2]} #{match[3]}"
        end
        
        begin
          return Date.parse(date_str)
        rescue Date::Error
          next
        end
      end
    end
    
    # Try to find any date in the document
    date_match = @content.match(/(\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4})/)
    if date_match
      begin
        return Date.parse(date_match[1])
      rescue Date::Error
        nil
      end
    end
    
    nil
  end

  def extract_agreement_period
    patterns = [
      /(?:period|duration|term)[:\s]+([^\n\r]+)/i,
      /for\s+a\s+(?:period\s+of\s+)?([^\n\r]+)/i,
      /(\d+\s+(?:months?|years?|days?))/i,
      /(?:commencing\s+from|starting\s+from)[:\s]+([^\n\r]+)/i,
      /(?:valid\s+for|effective\s+for)[:\s]+([^\n\r]+)/i
    ]
    
    extract_by_patterns(patterns)
  end

  def extract_by_patterns(patterns)
    patterns.each do |pattern|
      match = @content.match(pattern)
      if match && match[1]
        result = match[1].strip
        # Clean up common artifacts
        result = result.gsub(/[:\-_]+$/, '').strip
        return result if result.present?
      end
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
end
