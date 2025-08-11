#!/usr/bin/env ruby

# Debug script to understand why validation is failing

test_names = [
  "Mr.Dhamale Devram Vishwasrao",
  "Mr.Reddy Arulraj"
]

test_names.each_with_index do |name, i|
  puts "Testing name #{i+1}: '#{name}'"
  puts "  Length: #{name.length}"
  puts "  Length >= 8: #{name.length >= 8}"
  puts "  Matches title pattern: #{name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s+[A-Z][a-zA-Z]{2,}/i)}"
  puts "  Space count: #{name.count(' ')} (>= 2: #{name.count(' ') >= 2})"
  
  words = name.split(' ')
  puts "  Words: #{words.inspect}"
  puts "  All words >= 2 chars: #{words.all? { |word| word.length >= 2 }}"
  
  # Check each word individually
  words.each_with_index do |word, j|
    puts "    Word #{j+1}: '#{word}' (length: #{word.length})"
  end
  
  puts "  Overall validation: #{name.present? && 
                               name.length >= 8 && 
                               name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s+[A-Z][a-zA-Z]{2,}/i) &&
                               name.count(' ') >= 2 &&
                               name.split(' ').all? { |word| word.length >= 2 }}"
  puts
end
