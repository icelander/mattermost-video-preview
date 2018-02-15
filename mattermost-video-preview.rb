#!/usr/bin/ruby
require 'json'
require 'yaml'
require 'rest_client'
require 'mediainfo'
require 'digest'
require 'syslog/logger'

Log = Syslog::Logger.new 'mvp'
Log.info 'Running Mattermost Video Preview'

###
# Configuration
# 
# Stored in a file named video_preview_config.yaml
# Use video_preview_config.example.yaml as a template
###
Config = YAML::load_file(__dir__ + '/video_preview_config.yaml')

###
# Calls mattermost using the default Mattermost URL from the configuration
# 
# * data is a hash containing the data to send. Note that channel, username, and icon_url are reserved
# * url is the Mattermost URL defined above. This can be overridden for debugging
# * header is the default headers. This shouldn't need modified, but it's nice to have
###
def call_mattermost (data = {}, url = [Config['Mattermost']['url'], 'hooks', Config['Mattermost']['webhook_code']].join('/'), header = {content_type: :json, accept: :json})
	if !data.has_key?(:login_id)
		payload = data.merge(Config['DefaultPayload'])
	else
		payload = data
	end

	# Just in case, though we may not need text
	unless payload.has_key?(:text) or payload.has_key?(:attachments)
		payload['text'] = 'This was triggered on: ' + Time.now.strftime("%d/%m/%Y %H:%M") #Feel free to change this
	end

	response = RestClient.post url, payload.to_json, {content_type: :json, accept: :json}

	return response
end

##
# upload_file - moves the file to the webserver from the config file
# - filename: The full path of the image file
# - video_filename: Used to generate a unique MD5 hash for each image file
##
def upload_file (filename, video_filename)
	# new filename is the md5 of the old filename, plus "jpg"
	new_filename = Digest::MD5.hexdigest video_filename
	new_filename += '.jpg'

	FileUtils.mv(filename, [Config['WebServer']['webroot'], Config['WebServer']['preview_dir'], new_filename].join('/'))

	return [Config['WebServer']['url'], Config['WebServer']['preview_dir'], new_filename].join('/')
end

##
# Generates previews for each movie file in the transcode directory
# - filename: The full path of the video file to output
# - options: allows you to pass the following values for configuration. If not set they'll be pulled from your config
# 	- framegrab_grid: (string) Something like '5x6' or '2x4' to specify the size of the grid
# 	- framegrab_interval: (integer) The interval at which to grab frames in seconds. If set to zero it will determine it based on grid size and duration
#   - framegrab_height: (integer) The height of the generated frames in pixels.
##
def generate_previews(filename, options = {})
	framegrab_grid = options['framegrab_grid'] || Config['PreviewSettings']['default_grid']
	framegrab_interval = options['framegrab_interval'] || Config['PreviewSettings']['default_interval']
	framegrab_height = options['framegrab_height'] || Config['PreviewSettings']['default_height']

	base_filename = File.basename(filename)
	filesize = File.size(filename)
	file_info = Mediainfo.new filename

	if framegrab_interval.to_i == 0
		total_images = 1
		framegrab_grid.split('x').each do |x|
			total_images *= x.to_i
		end
		framegrab_interval = file_info.duration / total_images
	end

	count = 0
	units = ['bytes', 'KB', 'MB', 'GB', 'TB']
	loop do
		break if filesize < 1024.0
		count += 1
		filesize /= 1024.0
	end

	pretty_filesize = filesize.round(2).to_s + ' ' + units[count]

	duration = file_info.duration
	remainder = 0
	count = 0
	units = ['sec','min','h']
	loop do
		break if duration < 60
		count += 1
		remainder = duration % 60
		duration /= 60
	end

	pretty_duration = duration.round(0).to_s + ' ' + units[count]

	if remainder > 0
		pretty_duration += ' ' + remainder.round(0).to_s + ' ' + units[count-1]
	end

	command = "ffmpeg -loglevel panic -y -i \"#{filename}\" -frames 1 -q:v 1 -vf \"select='isnan(prev_selected_t)+gte(t-prev_selected_t\," + framegrab_interval.to_s + ")',scale=-1:" + framegrab_height.to_s + ",tile=" + framegrab_grid + "\" '/tmp/video_preview.jpg'"
	# puts command
	if system(command)
	# 	# Now that the preview is generated, post it to Mattermost
		if !(uploaded_file_url = upload_file('/tmp/video_preview.jpg', base_filename))
			call_mattermost({:text => "We ran into a problem uploading the file. Have someone look at this!"})
		else
			message = "![#{base_filename}](#{uploaded_file_url})\n\n"
			message+= "|#{base_filename}|[(preview)](#{uploaded_file_url})|\n"
			message+= "|-|-:|\n"
			message+= "|File Size| **#{pretty_filesize}**|\n"
			message+= "|Duration| **#{pretty_duration}**|\n"
			message+= "|Format| **#{file_info.format}**|"

			actions = Config['FileOperations']
			attachments_actions = []
			actions.keys.each do |key|
				action_hash = {
					'name': key,
					'integration': {
						'url': [Config['Webhook']['url'], 'run-command'].join('/'),
						'context': {
							'command': key,
							'filename': File.realpath(filename)
						}
					}
				}

				attachments_actions.push(action_hash)
			end


			attachments = [
    		{
      			"text": message,
      			"actions": attachments_actions
		    }]

			payload = {:attachments => attachments}

			call_mattermost(payload)
		end
	else
		Log.error "There was an error running the command: #{command}"
		call_mattermost({:text => "### DANGER WILL ROBINSON\nERROR"})
	end

end

##
# Runs the command defined in the config file
# - input_filename: The full path of the file you want to run the command on
# - file_operation: One of the defined file operations in the config file
##
def run_command(input_filename, file_operation)
	Log.info "Inside run_command"
	if !Config['FileOperations'].key?(file_operation)
		return "#{file_operation} isn't a valid preset"
	end

	transcode_settings = Config['FileOperations'][file_operation]

	Log.info transcode_settings.to_s

	begin
		if !transcode_settings.key?('command')
			return "#{file_operation} doesn't have a command"
		end

		command_template = transcode_settings['command']
		filename = File.basename(input_filename)
		base_filename = File.basename(input_filename, File.extname(input_filename))

		
		if transcode_settings.key?('location')
			output_filename = [transcode_settings['location'], base_filename].join('/')
		else
			output_filename = [Config['WebServer']['webroot'], Config['WebServer']['transcode_dir'], base_filename].join('/')
		end

		command = command_template % {input_filename:input_filename, output_filename: output_filename}

		Log.info command

		# Update the channel to let them know what's happening
		call_mattermost({:text => "Running command #{file_operation} on file #{filename}"})

		if system(command)
			if transcode_settings.key?('text')
				output_text = transcode_settings['text'] % {input_filename:input_filename, output_filename: output_filename}
			else
				output_text = "Finished running command #{file_operation} on file #{filename}"
			end
			
			call_mattermost({:text => output_text})	
		else
			call_mattermost({:text => "ERROR: Could not run command #{file_operation} on file #{filename}"})
		end

	rescue Exception => e
		Log.error e.to_s
		return 'There was an error'
	end
end

case ARGV[0]
when 'preview'
	Log.info 'Generating a preview'
	if File.file?(ARGV[1])
		generate_previews(ARGV[1])
	else
		Log.error "#{ARGV[1]} isn't a file."
	end
when 'run_command'
	request_info = JSON.parse(ARGV[1])
	command = request_info['context']['command']
	file = request_info['context']['filename']

	if File.file?(file)
		Log.info "Running command #{command} on file #{file}"
		Log.info run_command(file, command)
	else
		Log.error "#{file} isn't a file."
	end
else
	Log.error "#{ARGV[0]} isn't a valid command"
end