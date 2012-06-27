# -*- coding: utf-8 -*-

def self.comma(x)
  x.to_s.gsub(/(\d)(?=\d{3}+(\.\d*)?$)/, '\1,')
end

def self.to_kb(bytes)
  kb = bytes/1024.0
  if kb > 1.0
    return "#{sprintf "%0.2f", kb} KB"
  end
  "#{bytes} bytes"
end

def self.reckon_missing_tools(tools = [])
  missing = []
  tools.each do |tool|
    missing << tool if %x[which #{tool}].length == 0
  end
  missing
end

def self.process_jpeg(file_path)
  self.process_jpg(file_path)
end

def self.process_jpg(file_path)
  %x[ jpegtran -copy none -optimize -perfect -progressive #{file_path} > #{file_path}.p ]
  prog_size = File.size?("#{file_path}.p")

  %x[ jpegtran -copy none -optimize -perfect #{file_path} > #{file_path}.np ]
  nonprog_size = File.size?("#{file_path}.np")

  if prog_size < nonprog_size
    File.delete("#{file_path}.np")
    File.rename("#{file_path}.p", "#{file_path}.n")
    return 'P'
  else
    File.delete("#{file_path}.p")
    File.rename("#{file_path}.np", "#{file_path}.n")
    return nil
  end
end

def self.process_png(file_path)
  %x[ pngcrush -q -rem alla -reduce -brute #{file_path} #{file_path}.n ]
  return nil
end

def self.process_gif(file_path)
  %x[ gifsicle -O2 #{file_path} > #{file_path}.n ]
  return nil
end

missing_tools = reckon_missing_tools %w[jpegtran gifsicle pngcrush]
if missing_tools.size > 0
  puts "Image optimization requires the following tools to be installed: #{ missing_tools.join(', ') }"
  puts "Please verify they are installed and loaded into your path and try again."

  exit!
end

start = '.'

if ARGV[0] != nil
  start = ARGV[0]
end

# create log files
@log  = Hash.new
@logs = %w[status report skip]
@logs.each{ |x| @log[x.to_sym] = File.new(File.join(start, "#{x}.log"), 'w+') }

msg = "Processing JPG, PNG and GIF files in '#{start}', recursive"
@log[:status].puts msg; @log[:report].puts msg; puts msg + " - This may take several minutes when processing larger files."

# start now
start_time = Time.now.to_s

# DO NOT CHANGE THE FOLLOWING LINE OR GOD SHALL SMITE THEE!!
file_pattern  = File.join(start, '**', '*.{gif,jpeg,jpg,png}')

# generate list of files
file_list = Dir.glob file_pattern

# get a count of files to be processed
msg = "Files to process: #{comma file_list.size}"
@log[:status].puts msg; @log[:report].puts msg; puts msg

proc_cnt = 0
skip_cnt = 0
savings = {:old => Array.new, :new => Array.new}

file_list.each_with_index do |f,cnt|
  @log[:status].puts "Processing: #{comma cnt+1}/#{comma file_list.size} #{f.to_s}"

  # save ext
  extension = File.extname(f).delete('.')

  # check extension matches file type, if not log & skip processing, 
  cmd = "file -b #{f} | awk '{print $1}'"
  ext_check = %x[#{cmd}].strip.downcase
  ext_check.gsub!(/jpeg/,'jpg')
  if ext_check != extension
    msg = "\t#{f.to_s} is a: '#{ext_check}' not: '#{extension}' ..skipping"
    @log[:status].puts msg
    @log[:skip].puts msg
    skip_cnt = skip_cnt + 1
    next
  end

  # process file based on ext
  status_code = self.send("process_#{extension}", f)

  # get old & new file size
  old_size = File.size?(f).to_f 
  new_size = File.size?("#{f}.n").to_f

  # keep smaller file, delete bigger file, rename new file to old (if smaller)
  if new_size < old_size
    File.delete(f)
    File.rename("#{f}.n", f)
  else
    new_size = old_size
    File.delete("#{f}.n")
  end

  # track file sizes
  savings[:old] << old_size
  savings[:new] << new_size

  reduction = 100.0 - (new_size/old_size*100.0)

  @log[:status].puts "Output: #{status_code || ' '} | #{sprintf "%0.2f", reduction}% | #{comma old_size.to_i} -> #{comma new_size.to_i} (#{to_kb(old_size.to_i - new_size.to_i)})"
  proc_cnt = proc_cnt + 1
end

# add totals
total_old = savings[:old].inject(0){|sum,item| sum + item}
total_new = savings[:new].inject(0){|sum,item| sum + item}
total_reduction = 100.0 - (total_new/total_old*100.0)

msg = "Started at: #{start_time}\nFinished at: #{Time.now.to_s}" 
@log[:status].puts msg; @log[:report].puts msg; puts msg

msg = "Files: #{comma file_list.size}\nSkipped: #{comma skip_cnt}\nProcessed: #{comma(proc_cnt)}"
@log[:status].puts msg; @log[:report].puts msg; puts msg

msg = "Total savings:\n#{sprintf "%0.2f", total_reduction}% | #{comma total_old.to_i} -> #{comma total_new.to_i} (#{to_kb(total_old.to_i - total_new.to_i)})"
@log[:status].puts msg; @log[:report].puts msg; puts msg

# close files
@logs.each{ |x| @log[x.to_sym].close }
