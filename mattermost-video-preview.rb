#!/usr/bin/ruby
require 'json'
require 'yaml'
require 'rest_client'
require 'mediainfo'
require 'digest'

###
# Configuration
# 
# Stored in a file named video_preview_config.yaml
# Here's an example:                                    
# 	MattermostUrl: https://mattermost.example.com/hooks/1yfTV9pYML26dLjsWp8QZrvu2W
# 	WatchDirectory: '/home/user/transcode'
# 	DefaultPayload:
# 	  channel: notifications
# 	  username: Transcode Notifier
# 	  icon_url: https://i.imgur.com/hsUBcr7.png
###
Config = YAML::load_file('video_preview_config.yaml')

###
# Calls mattermost using the default Mattermost URL from the configuration
# 
# * data is a hash containing the data to send. Note that channel, username, and icon_url are reserved
# * url is the Mattermost URL defined above. This can be overridden for debugging
# * header is the default headers. This shouldn't need modified, but it's nice to have
###
def call_mattermost (data = {}, url = Config['Mattermost']['url'], header = {'Content-Type': 'text/json'})
	
	if !data.has_key?(:login_id)
		payload = data.merge(Config['DefaultPayload'])
	else
		payload = data
	end

	# puts payload

	# Just in case, though we may not need text
	unless payload.has_key?(:text)
		payload['text'] = 'This was triggered on: ' + Time.now.strftime("%d/%m/%Y %H:%M") #Feel free to change this
	end

	response = RestClient.post url, payload.to_json, {content_type: :json, accept: :json}

	return response
end


def get_auth_token()
	response = call_mattermost({ :login_id => Config['Mattermost']['username'], 
								 :password => Config['Mattermost']['password'] }, 
								 Config['Mattermost']['url'] + '/api/v4/users/login')
	
	return response.headers['token']
end

def upload_file (filename, video_filename)
	# Uploading a file in Mattermost is hard. Copying a file to a web server is easy

	# new filename is the md5 of the old filename, plus "jpg"
	new_filename = Digest::MD5.hexdigest video_filename
	new_filename += '.jpg'

	FileUtils.mv(filename, [Config['WebServer']['webroot'], Config['WebServer']['preview_dir'], new_filename].join('/'))

	return [Config['WebServer']['url'], Config['WebServer']['preview_dir'], new_filename].join('/')
end

# Generates previews for each movie file in the transcode directory
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

	# puts "Filesize #{pretty_filesize}"
	# puts "Duration: #{pretty_duration}"
	# puts file_info.format

	# abort
	# message = "### Gadzooks!\nWe found the file! #{base_filename} Give me a minute to generate a preview."
	# abort
	command = "ffmpeg -loglevel panic -y -i \"#{filename}\" -frames 1 -q:v 1 -vf \"select='isnan(prev_selected_t)+gte(t-prev_selected_t\," + framegrab_interval.to_s + ")',scale=-1:" + framegrab_height.to_s + ",tile=" + framegrab_grid + "\" '/tmp/video_preview.jpg'"
	# puts command
	# upload_file('video_preview.jpg', base_filename)
	###
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
			call_mattermost({:text => message})
		end
	else
		call_mattermost({:text => "### DANGER WILL ROBINSON\nERROR"})
	end


end

if File.file?(ARGV[0])
	generate_previews(ARGV[0])
end


