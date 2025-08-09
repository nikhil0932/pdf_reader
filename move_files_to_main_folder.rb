#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'

class FileFlattener
  def initialize(source_dir, target_dir = nil, options = {})
    @source_dir = File.expand_path(source_dir)
    @target_dir = target_dir ? File.expand_path(target_dir) : @source_dir
    @dry_run = options[:dry_run] || false
    @preserve_structure = options[:preserve_structure] || false
    @file_extensions = options[:file_extensions] || []
    @exclude_dirs = options[:exclude_dirs] || ['.git', '.svn', 'node_modules', '.DS_Store']
    @conflict_resolution = options[:conflict_resolution] || :rename # :rename, :skip, :overwrite
  end

  def flatten_files
    puts "#{@dry_run ? '[DRY RUN] ' : ''}Moving files from subfolders to main folder"
    puts "Source directory: #{@source_dir}"
    puts "Target directory: #{@target_dir}"
    puts "File extensions filter: #{@file_extensions.empty? ? 'All files' : @file_extensions.join(', ')}"
    puts "-" * 60

    unless Dir.exist?(@source_dir)
        
      puts "Error: Source directory does not exist: #{@source_dir}"
      return false
    end

    # Create target directory if it doesn't exist
    unless @dry_run
      FileUtils.mkdir_p(@target_dir) unless Dir.exist?(@target_dir)
    end

    moved_count = 0
    skipped_count = 0
    error_count = 0

    # Find all files in subdirectories
    files_to_move = find_files_in_subdirectories

    puts "Found #{files_to_move.length} files to process\n\n"

    files_to_move.each_with_index do |(source_path, relative_path), index|
      begin
        target_filename = generate_target_filename(source_path, relative_path)
        target_path = File.join(@target_dir, target_filename)

        puts "[#{index + 1}/#{files_to_move.length}] Processing: #{relative_path}"

        if File.exist?(target_path) && source_path != target_path
          case @conflict_resolution
          when :skip
            puts "  → SKIPPED (file already exists): #{target_filename}"
            skipped_count += 1
            next
          when :overwrite
            puts "  → OVERWRITING: #{target_filename}"
          when :rename
            target_path = find_unique_filename(target_path)
            target_filename = File.basename(target_path)
            puts "  → RENAMED TO: #{target_filename}"
          end
        end

        unless @dry_run
          FileUtils.mv(source_path, target_path)
        end

        puts "  → MOVED TO: #{target_filename}"
        moved_count += 1

      rescue => e
        puts "  → ERROR: #{e.message}"
        error_count += 1
      end
    end

    puts "\n" + "=" * 60
    puts "Summary:"
    puts "  Files moved: #{moved_count}"
    puts "  Files skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts "  Total processed: #{files_to_move.length}"

    # Clean up empty directories
    unless @dry_run
      cleanup_empty_directories
    end

    true
  end

  private

  def find_files_in_subdirectories
    files = []
    
    Dir.glob(File.join(@source_dir, "**", "*"), File::FNM_DOTMATCH).each do |path|
      next if File.directory?(path)
      next if path == @source_dir
      
      relative_path = Pathname.new(path).relative_path_from(Pathname.new(@source_dir)).to_s
      
      # Skip files in excluded directories
      next if @exclude_dirs.any? { |dir| relative_path.include?("/#{dir}/") || relative_path.start_with?("#{dir}/") }
      
      # Skip files already in the root directory
      next unless relative_path.include?('/')
      
      # Filter by file extensions if specified
      if @file_extensions.any?
        file_ext = File.extname(path).downcase.delete('.')
        next unless @file_extensions.include?(file_ext)
      end
      
      files << [path, relative_path]
    end
    
    files.sort_by { |_, relative_path| relative_path }
  end

  def generate_target_filename(source_path, relative_path)
    if @preserve_structure
      # Replace directory separators with underscores to preserve folder structure
      relative_path.gsub('/', '_')
    else
      # Just use the original filename
      File.basename(source_path)
    end
  end

  def find_unique_filename(target_path)
    return target_path unless File.exist?(target_path)
    
    dir = File.dirname(target_path)
    basename = File.basename(target_path, File.extname(target_path))
    extension = File.extname(target_path)
    
    counter = 1
    loop do
      new_path = File.join(dir, "#{basename}_#{counter}#{extension}")
      return new_path unless File.exist?(new_path)
      counter += 1
    end
  end

  def cleanup_empty_directories
    puts "\nCleaning up empty directories..."
    
    Dir.glob(File.join(@source_dir, "**", "*"), File::FNM_DOTMATCH)
       .select { |path| File.directory?(path) }
       .reject { |path| path == @source_dir }
       .sort_by(&:length)
       .reverse
       .each do |dir|
      
      begin
        next if @exclude_dirs.any? { |excluded| dir.include?(excluded) }
        
        if Dir.empty?(dir)
          puts "  Removing empty directory: #{Pathname.new(dir).relative_path_from(Pathname.new(@source_dir))}"
          Dir.rmdir(dir)
        end
      rescue => e
        puts "  Could not remove directory #{dir}: #{e.message}"
      end
    end
  end
end

# Command line interface
if __FILE__ == $0
  require 'optparse'

  options = {
    dry_run: false,
    preserve_structure: false,
    file_extensions: [],
    conflict_resolution: :rename
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] SOURCE_DIR [TARGET_DIR]"
    opts.separator ""
    opts.separator "Move all files from subdirectories to a main folder"
    opts.separator ""
    opts.separator "Options:"

    opts.on("-d", "--dry-run", "Show what would be moved without actually moving files") do
      options[:dry_run] = true
    end

    opts.on("-p", "--preserve-structure", "Include folder names in filename (e.g., folder_file.txt)") do
      options[:preserve_structure] = true
    end

    opts.on("-e", "--extensions EXTENSIONS", "Only move files with these extensions (comma-separated, e.g., pdf,txt,docx)") do |extensions|
      options[:file_extensions] = extensions.downcase.split(',').map(&:strip)
    end

    opts.on("-c", "--conflict STRATEGY", "How to handle filename conflicts: rename, skip, overwrite (default: rename)") do |strategy|
      valid_strategies = [:rename, :skip, :overwrite]
      strategy_sym = strategy.to_sym
      if valid_strategies.include?(strategy_sym)
        options[:conflict_resolution] = strategy_sym
      else
        puts "Error: Invalid conflict resolution strategy. Use: #{valid_strategies.join(', ')}"
        exit 1
      end
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  if ARGV.empty?
    puts "Error: Please specify a source directory"
    puts "Use --help for usage information"
    exit 1
  end

  source_dir = ARGV[0]
  target_dir = ARGV[1] # Optional, defaults to source_dir

  flattener = FileFlattener.new(source_dir, target_dir, options)
  success = flattener.flatten_files

  exit success ? 0 : 1
end
