namespace :export do
  desc "Export all PDF documents to CSV"
  task :csv, [:output_file] => :environment do |task, args|
    require 'csv'
    
    output_file = args[:output_file] || "pdf_documents_#{Date.current.strftime('%Y%m%d')}.csv"
    
    puts "Exporting PDF documents to CSV..."
    puts "Output file: #{output_file}"
    
    CSV.open(output_file, 'w', write_headers: true, headers: [
      'ID', 'Filename', 'Title', 'Licensor', 'Licensee', 'Address',
      'Agreement Date', 'Start Date', 'End Date', 'Agreement Period', 'Filtered Data Preview'
    ]) do |csv|
      
      # Sort so that records with empty licensor and licensee appear at the bottom
      sorted_documents = PdfDocument.all.sort_by do |doc|
        licensor_present = doc.licensor.present?
        licensee_present = doc.licensee.present?
        
        if licensor_present && licensee_present
          [0, doc.id] # Both present - sort by ID within this group
        elsif licensor_present || licensee_present
          [1, doc.id] # One present - sort by ID within this group  
        else
          [2, doc.id] # Both empty - sort by ID within this group (at bottom)
        end
      end
      
      sorted_documents.each do |doc|
        csv << [
          doc.id,
          doc.filename,
          doc.title,
          doc.licensor,
          doc.licensee,
          doc.address,
          doc.agreement_date&.strftime('%Y-%m-%d'),
          doc.start_date&.strftime('%Y-%m-%d'),
          doc.end_date&.strftime('%Y-%m-%d'),
          doc.agreement_period,
          doc.filtered_data&.truncate(100)
        ]
      end
    end
    
    count = PdfDocument.count
    puts "✅ Successfully exported #{count} documents to #{output_file}"
    puts "File size: #{File.size(output_file)} bytes"
  end

  desc "Export all PDF documents to Excel"
  task :excel, [:output_file] => :environment do |task, args|
    require 'caxlsx'
    
    output_file = args[:output_file] || "pdf_documents_#{Date.current.strftime('%Y%m%d')}.xlsx"
    
    puts "Exporting PDF documents to Excel..."
    puts "Output file: #{output_file}"
    
    package = Axlsx::Package.new
    workbook = package.workbook
    
    # Main data sheet
    workbook.add_worksheet(name: "PDF Documents") do |sheet|
      # Styles
      header_style = sheet.styles.add_style(
        bg_color: "366092",
        fg_color: "FFFFFF", 
        b: true,
        alignment: { horizontal: :center }
      )
      
      date_style = sheet.styles.add_style(format_code: "yyyy-mm-dd")
      datetime_style = sheet.styles.add_style(format_code: "yyyy-mm-dd hh:mm:ss")
      wrap_style = sheet.styles.add_style(alignment: { wrap_text: true, vertical: :top })
      
      # Headers
      headers = [
        'ID', 'Filename', 'Title', 'Licensor', 'Licensee', 'Address',
        'Agreement Date', 'Start Date', 'End Date', 'Agreement Period', 'Filtered Data Preview'
      ]
      
      sheet.add_row headers, style: header_style
      
      # Data - Sort so that records with empty licensor and licensee appear at the bottom
      # Custom sorting: records with both licensor and licensee present first,
      # then records with only one present, then records with both empty
      sorted_documents = PdfDocument.all.sort_by do |doc|
        licensor_present = doc.licensor.present?
        licensee_present = doc.licensee.present?
        
        if licensor_present && licensee_present
          [0, doc.id] # Both present - sort by ID within this group
        elsif licensor_present || licensee_present
          [1, doc.id] # One present - sort by ID within this group  
        else
          [2, doc.id] # Both empty - sort by ID within this group (at bottom)
        end
      end
      
      sorted_documents.each do |doc|
        sheet.add_row [
          doc.id,
          doc.filename,
          doc.title,
          doc.licensor,
          doc.licensee,
          doc.address,
          doc.agreement_date,
          doc.start_date,
          doc.end_date,
          doc.agreement_period,
          doc.filtered_data&.truncate(500)
        ], style: [
          nil, nil, nil, wrap_style, wrap_style, wrap_style,
          date_style, date_style, date_style, nil, wrap_style
        ]
      end
      
      # Column widths
      # ID, Filename, Title, Licensor, Licensee, Address, Agreement Date, Start Date, End Date, Agreement Period, Filtered Data Preview
      sheet.column_widths 5, 25, 25, 30, 30, 40, 15, 15, 15, 20, 50
    end
    
    # Summary sheet
    workbook.add_worksheet(name: "Summary") do |sheet|
      title_style = sheet.styles.add_style(b: true, sz: 16, fg_color: "366092")
      header_style = sheet.styles.add_style(b: true, bg_color: "E1E8F0")
      
      sheet.add_row ["PDF Documents Export Summary"], style: title_style
      sheet.add_row []
      
      total_docs = PdfDocument.count
      with_licensor = PdfDocument.where.not(licensor: [nil, '']).count
      with_licensee = PdfDocument.where.not(licensee: [nil, '']).count
      with_date = PdfDocument.where.not(agreement_date: nil).count
      with_address = PdfDocument.where.not(address: [nil, '']).count
      
      sheet.add_row ["Statistic", "Count", "Percentage"], style: header_style
      sheet.add_row ["Total Documents", total_docs, "100%"]
      sheet.add_row ["Documents with Licensor", with_licensor, "#{(with_licensor.to_f / total_docs * 100).round(1)}%"] if total_docs > 0
      sheet.add_row ["Documents with Licensee", with_licensee, "#{(with_licensee.to_f / total_docs * 100).round(1)}%"] if total_docs > 0
      sheet.add_row ["Documents with Agreement Date", with_date, "#{(with_date.to_f / total_docs * 100).round(1)}%"] if total_docs > 0
      sheet.add_row ["Documents with Address", with_address, "#{(with_address.to_f / total_docs * 100).round(1)}%"] if total_docs > 0
      
      sheet.add_row []
      sheet.add_row ["Export Date", Date.current.strftime("%Y-%m-%d")]
      sheet.add_row ["Export Time", Time.current.strftime("%H:%M:%S")]
      
      sheet.column_widths 30, 15, 15
    end
    
    package.serialize(output_file)
    
    count = PdfDocument.count
    puts "✅ Successfully exported #{count} documents to #{output_file}"
    puts "File size: #{File.size(output_file)} bytes"
  end

  desc "Export filtered PDF documents"
  task :filtered, [:format, :output_file, :date_from, :date_to, :licensor, :licensee] => :environment do |task, args|
    format = args[:format] || 'csv'
    date_from = args[:date_from]
    date_to = args[:date_to]
    licensor = args[:licensor]
    licensee = args[:licensee]
    
    # Build query
    query = PdfDocument.all
    query = query.where('agreement_date >= ?', date_from) if date_from.present?
    query = query.where('agreement_date <= ?', date_to) if date_to.present?
    query = query.where('licensor LIKE ?', "%#{licensor}%") if licensor.present?
    query = query.where('licensee LIKE ?', "%#{licensee}%") if licensee.present?
    
    documents = query.order(:created_at)
    count = documents.count
    
    puts "Found #{count} documents matching filters:"
    puts "  Date range: #{date_from} to #{date_to}" if date_from.present? || date_to.present?
    puts "  Licensor contains: #{licensor}" if licensor.present?
    puts "  Licensee contains: #{licensee}" if licensee.present?
    
    if count == 0
      puts "No documents found matching the specified filters."
      exit
    end
    
    case format.downcase
    when 'csv'
      output_file = args[:output_file] || "filtered_pdf_documents_#{Date.current.strftime('%Y%m%d')}.csv"
      export_filtered_csv(documents, output_file)
    when 'excel', 'xlsx'
      output_file = args[:output_file] || "filtered_pdf_documents_#{Date.current.strftime('%Y%m%d')}.xlsx"
      export_filtered_excel(documents, output_file)
    else
      puts "Error: Unsupported format '#{format}'. Use 'csv' or 'excel'."
      exit 1
    end
  end

  desc "Show export statistics"
  task :stats => :environment do
    total = PdfDocument.count
    with_licensor = PdfDocument.where.not(licensor: [nil, '']).count
    with_licensee = PdfDocument.where.not(licensee: [nil, '']).count
    with_date = PdfDocument.where.not(agreement_date: nil).count
    with_address = PdfDocument.where.not(address: [nil, '']).count
    
    puts "PDF Documents Export Statistics"
    puts "=" * 35
    puts "Total documents: #{total}"
    
    if total > 0
      puts "Documents with licensor: #{with_licensor} (#{(with_licensor.to_f / total * 100).round(1)}%)"
      puts "Documents with licensee: #{with_licensee} (#{(with_licensee.to_f / total * 100).round(1)}%)"
      puts "Documents with agreement date: #{with_date} (#{(with_date.to_f / total * 100).round(1)}%)"
      puts "Documents with address: #{with_address} (#{(with_address.to_f / total * 100).round(1)}%)"
      
      puts "\nRecent uploads:"
      PdfDocument.order(created_at: :desc).limit(5).each do |doc|
        puts "  - #{doc.filename || doc.title} (#{doc.created_at.strftime('%Y-%m-%d %H:%M')})"
      end
    else
      puts "No documents found in database."
    end
  end

  private

  def export_filtered_csv(documents, output_file)
    require 'csv'
    
    CSV.open(output_file, 'w', write_headers: true, headers: [
      'ID', 'Filename', 'Title', 'Licensor', 'Licensee', 'Address',
      'Agreement Date', 'Start Date', 'End Date', 'Agreement Period', 'Filtered Data Preview'
    ]) do |csv|
      
      documents.each do |doc|
        csv << [
          doc.id,
          doc.filename,
          doc.title,
          doc.licensor,
          doc.licensee,
          doc.address,
          doc.agreement_date&.strftime('%Y-%m-%d'),
          doc.start_date&.strftime('%Y-%m-%d'),
          doc.end_date&.strftime('%Y-%m-%d'),
          doc.agreement_period,
          doc.filtered_data&.truncate(100)
        ]
      end
    end
    
    puts "✅ Successfully exported #{documents.count} filtered documents to #{output_file}"
    puts "File size: #{File.size(output_file)} bytes"
  end

  def export_filtered_excel(documents, output_file)
    require 'caxlsx'
    
    package = Axlsx::Package.new
    workbook = package.workbook      workbook.add_worksheet(name: "Filtered PDF Documents") do |sheet|
      header_style = sheet.styles.add_style(
        bg_color: "366092",
        fg_color: "FFFFFF", 
        b: true,
        alignment: { horizontal: :center }
      )
      
      date_style = sheet.styles.add_style(format_code: "yyyy-mm-dd")
      datetime_style = sheet.styles.add_style(format_code: "yyyy-mm-dd hh:mm:ss")
      wrap_style = sheet.styles.add_style(alignment: { wrap_text: true, vertical: :top })
      
      headers = [
        'ID', 'Filename', 'Title', 'Licensor', 'Licensee', 'Address',
        'Agreement Date', 'Start Date', 'End Date', 'Agreement Period', 'Filtered Data Preview'
      ]
      
      sheet.add_row headers, style: header_style
      
      documents.each do |doc|
        sheet.add_row [
          doc.id,
          doc.filename,
          doc.title,
          doc.licensor,
          doc.licensee,
          doc.address,
          doc.agreement_date,
          doc.start_date,
          doc.end_date,
          doc.agreement_period,
          doc.filtered_data&.truncate(500)
        ], style: [
          nil, nil, nil, wrap_style, wrap_style, wrap_style,
          date_style, date_style, date_style, nil, wrap_style
        ]
      end
      
      # ID, Filename, Title, Licensor, Licensee, Address, Agreement Date, Start Date, End Date, Agreement Period, Filtered Data Preview
      sheet.column_widths 5, 25, 25, 30, 30, 40, 15, 15, 15, 20, 50
    end
    
    package.serialize(output_file)
    
    puts "✅ Successfully exported #{documents.count} filtered documents to #{output_file}"
    puts "File size: #{File.size(output_file)} bytes"
  end
end
