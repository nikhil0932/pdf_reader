#!/usr/bin/env ruby

# PDF Data Export Script
# Usage: ruby export_data.rb [format] [output_file]

require 'bundler/setup'
require_relative 'config/environment'

class PdfDataExporter
  def initialize(format = 'csv', output_file = nil)
    @format = format.downcase
    @output_file = output_file || default_filename
  end

  def export_all
    puts "Exporting all PDF documents..."
    puts "Format: #{@format.upcase}"
    puts "Output: #{@output_file}"
    puts ""

    documents = PdfDocument.all
    count = documents.count

    if count == 0
      puts "❌ No documents found in database."
      return
    end

    case @format
    when 'csv'
      export_csv(documents)
    when 'excel', 'xlsx'
      export_excel(documents)
    else
      puts "❌ Unsupported format: #{@format}"
      puts "Supported formats: csv, excel, xlsx"
      return
    end

    display_summary(count)
  end

  def self.show_usage
    puts "PDF Data Export Script"
    puts "====================="
    puts ""
    puts "Usage:"
    puts "  ruby export_data.rb [format] [output_file]"
    puts ""
    puts "Formats:"
    puts "  csv   - Comma-separated values (default)"
    puts "  excel - Microsoft Excel format"
    puts "  xlsx  - Microsoft Excel format"
    puts ""
    puts "Examples:"
    puts "  ruby export_data.rb"
    puts "  ruby export_data.rb csv"
    puts "  ruby export_data.rb excel my_data.xlsx"
    puts "  ruby export_data.rb csv /path/to/output.csv"
    puts ""
    puts "Default output files:"
    puts "  CSV:   pdf_documents_YYYYMMDD.csv"
    puts "  Excel: pdf_documents_YYYYMMDD.xlsx"
  end

  private

  def default_filename
    date_str = Date.current.strftime('%Y%m%d')
    case @format
    when 'csv'
      "pdf_documents_#{date_str}.csv"
    when 'excel', 'xlsx'
      "pdf_documents_#{date_str}.xlsx"
    end
  end

  def export_csv(documents)
    require 'csv'

    CSV.open(@output_file, 'w', write_headers: true, headers: csv_headers) do |csv|
      documents.find_each do |doc|
        csv << format_document_row(doc)
      end
    end
  end

  def export_excel(documents)
    require 'caxlsx'

    package = Axlsx::Package.new
    workbook = package.workbook

    # Main data sheet
    create_data_sheet(workbook, documents)
    
    # Summary sheet
    create_summary_sheet(workbook, documents)

    package.serialize(@output_file)
  end

  def create_data_sheet(workbook, documents)
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
      sheet.add_row csv_headers, style: header_style

      # Data rows
      documents.find_each do |doc|
        sheet.add_row format_document_row(doc), style: [
          nil, nil, nil, wrap_style, wrap_style, wrap_style,
          date_style, nil, nil, datetime_style,
          datetime_style, datetime_style, wrap_style, wrap_style
        ]
      end

      # Auto-fit columns
      sheet.column_widths 5, 25, 25, 30, 30, 40, 15, 20, 10, 20, 20, 20, 50, 50
    end
  end

  def create_summary_sheet(workbook, documents)
    workbook.add_worksheet(name: "Summary") do |sheet|
      title_style = sheet.styles.add_style(b: true, sz: 16, fg_color: "366092")
      header_style = sheet.styles.add_style(b: true, bg_color: "E1E8F0")

      # Title and stats
      sheet.add_row ["PDF Documents Export Summary"], style: title_style
      sheet.add_row []

      total_docs = documents.count
      with_licensor = documents.count { |doc| doc.licensor.present? }
      with_licensee = documents.count { |doc| doc.licensee.present? }
      with_date = documents.count { |doc| doc.agreement_date.present? }

      sheet.add_row ["Statistic", "Count", "Percentage"], style: header_style
      sheet.add_row ["Total Documents", total_docs, "100%"]
      
      if total_docs > 0
        sheet.add_row ["Documents with Licensor", with_licensor, "#{(with_licensor.to_f / total_docs * 100).round(1)}%"]
        sheet.add_row ["Documents with Licensee", with_licensee, "#{(with_licensee.to_f / total_docs * 100).round(1)}%"]
        sheet.add_row ["Documents with Agreement Date", with_date, "#{(with_date.to_f / total_docs * 100).round(1)}%"]
      end

      sheet.add_row []
      sheet.add_row ["Export Date", Date.current.strftime("%Y-%m-%d")]
      sheet.add_row ["Export Time", Time.current.strftime("%H:%M:%S")]

      sheet.column_widths 30, 15, 15
    end
  end

  def csv_headers
    [
      'ID', 'Filename', 'Title', 'Licensor', 'Licensee', 'Address',
      'Agreement Date', 'Agreement Period', 'Page Count', 'Uploaded At',
      'Created At', 'Updated At', 'Content Preview', 'Filtered Data Preview'
    ]
  end

  def format_document_row(doc)
    [
      doc.id,
      doc.filename,
      doc.title,
      doc.licensor,
      doc.licensee,
      doc.address,
      doc.agreement_date&.strftime('%Y-%m-%d'),
      doc.agreement_period,
      doc.page_count,
      doc.uploaded_at&.strftime('%Y-%m-%d %H:%M:%S'),
      doc.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      doc.updated_at.strftime('%Y-%m-%d %H:%M:%S'),
      doc.content&.truncate(100),
      doc.filtered_data&.truncate(100)
    ]
  end

  def display_summary(count)
    puts ""
    puts "✅ Export completed successfully!"
    puts "📊 Documents exported: #{count}"
    puts "📁 Output file: #{@output_file}"
    puts "📏 File size: #{File.size(@output_file)} bytes (#{(File.size(@output_file) / 1024.0).round(2)} KB)"
    puts ""
    puts "You can now open the file with:"

    case @format
    when 'csv'
      puts "  - Excel, LibreOffice Calc, or any spreadsheet application"
      puts "  - Text editor for raw CSV data"
    when 'excel', 'xlsx'
      puts "  - Microsoft Excel"
      puts "  - LibreOffice Calc"
      puts "  - Google Sheets (upload the file)"
    end
  end
end

# Command line interface
if __FILE__ == $0
  case ARGV[0]
  when 'help', '--help', '-h', nil
    if ARGV[0].nil? && PdfDocument.count > 0
      # If no arguments but data exists, show quick export options
      puts "Quick Export Options:"
      puts "  ruby export_data.rb csv     # Export to CSV"
      puts "  ruby export_data.rb excel   # Export to Excel"
      puts ""
      puts "Or use 'help' for full usage information:"
      puts "  ruby export_data.rb help"
    else
      PdfDataExporter.show_usage
    end
  else
    format = ARGV[0] || 'csv'
    output_file = ARGV[1]
    
    exporter = PdfDataExporter.new(format, output_file)
    exporter.export_all
  end
end
