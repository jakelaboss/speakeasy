#!/sbin/ruby
require "google/cloud/speech"
require "wavefile"
require 'audio_trimmer'
require 'fileutils'
include WaveFile

# The name of the audio file to transcribe
def get_file()
  puts("Please enter a file path: ")
  for arg in ARGV
  	name = arg
  end
  print meta_data(name)
  name
end

def meta_data(file_name)
  puts "Metadata for #{file_name}:"
  begin
    reader = Reader.new(file_name)
    puts "  Readable by this program  #{reader.readable_format? ? 'Yes' : 'No'}"
    puts "  Audio Format:          #{reader.native_format.audio_format}"
    puts "  Channels:              #{reader.native_format.channels}"
    puts "  Bits per sample:       #{reader.native_format.bits_per_sample}"
    puts "  Samples per second:    #{reader.native_format.sample_rate}"
    puts "  Bytes per second:      #{reader.native_format.byte_rate}"
    puts "  Sample frame count:    #{reader.total_sample_frames}"
    duration = reader.total_duration
    formatted_duration = duration.hours.to_s.rjust(2, "0") << ":" <<
                         duration.minutes.to_s.rjust(2, "0") << ":" <<
                         duration.seconds.to_s.rjust(2, "0") << ":" <<
                         duration.milliseconds.to_s.rjust(3, "0")
    puts "  Play time:             #{formatted_duration}"
  rescue InvalidFormatError
    puts "  Not a valid Wave file!"
  end
end

def trim_file(file_name)
  AudioTrimmer.new(input:File.expand_path(file_name))
end

def format_file(file)
  FileUtils.rm_rf(Dir.glob('formatted.wav'))
  system "ffmpeg -i #{file} -ac 1 -ar 48000 formatted.wav"
end

def split_file(file_name)
  Dir.mkdir('trim') unless Dir.exists?('trim')
  FileUtils.rm_rf(Dir.glob('trim/*'))
  trimmer = trim_file(file_name)
  reader = Reader.new(file_name)
  duration = reader.total_duration
  int = duration.seconds + (duration.minutes * 60)
  x = 0
  puts "splitting up the file to be processed..."
  while x <= int
    start = x
    finish = x + 30
    filename = "trim/#{x / 30}.wav"
    trimmer.trim start: start, finish: finish, output:File.expand_path(filename)
    puts "#{ 1 + x / 30} out of #{ 1 + int / 30} completed."
    x = x + 30
  end
  puts "Done."
end

def recognize_audio(outputname)
  Dir.mkdir('results') unless Dir.exists?('results')
	if File.exist?("results/#{outputname.gsub(/\..+/,"") }-transcription.txt")
    puts "Please look for your transcription in results."
    return
  end
  puts "Starting Transcription, this may take a few minutes:"
  transcription = ""

  speech = Google::Cloud::Speech.speech(version: :v1)
  trims = Dir["trim/*"].sort_by { |s| s.gsub(".wav","").gsub("trim/","").to_i}
  name = "#{outputname.gsub(/\..+/,"") }"
  # Dir.mkdir(name)

  for x in trims
    audio_file = File.binread x
    config = { sample_rate_hertz:        48_000,
      language_code:     "en-US"   }

    audio  = { content: audio_file }
    response = speech.recognize(config: config, audio: audio)

    results = response.results

    unless results.first.nil?
      results.each  do |r|
        r.alternatives.each do |alternatives|
          # File.open("#{name}/transcription-#{x.gsub(".wav","").gsub("trim/","").to_i}.txt", 'a') { |file| file.write(alternatives.transcript) }
          transcription = transcription.concat("#{alternatives.transcript} ")
        end
      end
    end
    puts "#{x.gsub(".wav","").gsub("trim/","").to_i} out of #{trims.length} completed."
  end
  puts "Success!"
  puts "writing file..."
  File.open("results/#{name}-transcription.txt", 'w') { |file| file.write(transcription) }
  puts "Please look for your transcription in results."
  transcription
end

def clean()
    FileUtils.rm_rf(Dir.glob('trim/*'))
    FileUtils.rm_rf(Dir.glob('trim'))
    FileUtils.rm_rf('formatted.wav')
end

def init(file_name)
  format_file(file_name)
  split_file('formatted.wav')
  recognize_audio(file_name)
  clean()
end

init(get_file())

