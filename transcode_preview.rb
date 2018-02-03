#!/usr/bin/ruby
require 'json'
require 'yaml'
require 'rest_client'

###
# Configuration
# 
# Stored in a file named transcode_config.yaml
# Here's an example:                                    
# 	MattermostUrl: https://mattermost.example.com/hooks/1yfTV9pYML26dLjsWp8QZrvu2W
# 	WatchDirectory: '/home/user/transcode'
# 	DefaultPayload:
# 	  channel: notifications
# 	  username: Transcode Notifier
# 	  icon_url: https://i.imgur.com/hsUBcr7.png
###
Config = YAML::load_file('transcode_config.yaml')


# Calls mattermost using the default Mattermost URL and the 
# 
# * data is a hash containing the data to send. Note that channel, username, and icon_url are reserved
# * url is the Mattermost URL defined above. This can be overridden for debugging
# * header is the default headers. This shouldn't need modified, but it's nice to have
def call_mattermost (data = {}, url = Config["MattermostUrl"], header = {'Content-Type': 'text/json'})
	
	if !data.has_key?(:login_id)
		payload = data.merge(Config["DefaultPayload"])
	else
		payload = data
	end

	# puts payload

	# Just in case, though we may not need text
	unless payload.has_key?(:text)
		payload[:text] = 'This was triggered on: ' + Time.now.strftime("%d/%m/%Y %H:%M") #Feel free to change this
	end

	response = RestClient.post url, payload.to_json, {content_type: :json, accept: :json}

	return response
end


def get_auth_token()
	response = call_mattermost({ :login_id => Config['login_id'], :password => Config['password'] }, 'http://localhost:8065/api/v4/users/login')
	
	return response.headers[:token]
end

def upload_file (filename, video_filename)
	files = {"files": open(filename, 'rb'), "filename": "#{video_filename} Preview"}

	# First, we authenticate it
	bearer_token = get_auth_token()
	
	headers = {'Authorization' => "Bearer #{bearer_token}"}

	# RestClient.post 'http://localhost:3000/foo', fields_hash.merge(:file => File.new('/path/to/file'))
	request = RestClient::Request.new(
		:method => :post,
		:url => 'http://localhost:8065/api/v4/files',
		:payload => {
			:multipart => true,
			:file => File.new(filename, 'rb'),
			:channel_id => DefaultPayload['channel']
			:filename => video_filename
		},
		:headers => headers
	)

	# response = RestClient.post 'http://localhost:8065/api/v4/files', content.merge({:file => File.new(filename, 'rb'), :filename => "#{video_filename} Preview"}), headers
	begin
		response = request.execute
	rescue => e
		puts request.headers
		puts "Error uploading file"
		puts e.response
	end

	# puts response
end


# Generates previews for each movie file in the transcode directory

def generate_previews(filename)
	base_filename = File.basename(filename)

	take_frames_once_this_many_seconds = '1'
	framegrab_grid = '5x6'
	framegrab_height = '120'

	# message = "### Gadzooks!\nWe found the file! #{base_filename} Give me a minute to generate a preview."
	# call_mattermost({:text => message})
	# ffmpeg -y -i "/angrydome/home/paul/transcode/S01E01 - Winter Is Coming.avi" video_preview.jpg
	command = "ffmpeg -y -i \"#{filename}\" -frames 1 -q:v 1 -vf \"select='isnan(prev_selected_t)+gte(t-prev_selected_t\," + take_frames_once_this_many_seconds + ")',scale=-1:" + framegrab_height + ",tile=" + framegrab_grid + "\" '/tmp/video_preview.jpg'"
	# puts command
	upload_file('/tmp/video_preview.jpg', base_filename)
	###
	# if system(command)
	# 	# Now that the preview is generated, post it to Mattermost
	# 	if !upload_file(filename, base_filename)
	# 		call_mattermost({:text => "We ran into a problem uploading the file. Have someone look at this!"})
	# 	end
	# else
	# 	call_mattermost({:text => "### DANGER WILL ROBINSON\nERROR"})
	# end
end

if File.file?(ARGV[0])
	
end
generate_previews(ARGV[0])

