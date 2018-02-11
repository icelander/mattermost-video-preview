# mattermost-video-preview

This Ruby script will generate preview images and clips for video files using the `ffmpeg` utility. By default it will generate a 5x6 grid of images from every 1 second of video, with each image being 120px tall. For example:

![An example of the generated image](https://i.imgur.com/pY4O1Tm.jpg "An example of the generated image")

You can also configure commands to run against these files in a YAML file to post process them. The default implementation includes commands for transcoding for Web, iPhone, Roku, and also deleting the file. This is great

## Dependencies

To use this you'll need to install the following:

 - [MediaInfo](https://www.github.com/icelander/mediainfo)
 - [RestClient](https://github.com/rest-client/rest-client)
 - `ffmpeg`

## Usage Instructions

First, create the file `video_preview_config.yaml` using `video_preview_config.example.yaml` as an example and configure it for your environment.

Next, call the script and pass the video file as the first parameter. For example

```
$ mattermost-video-preview.rb preview video_file.mp4
```

This will post a message to the specified channel with the preview image, some file information, and buttons to activate the configured commands.

![An example of the message posted](https://i.imgur.com/CDxQ6JF.jpg "An example of the message posted")

## Version History

 - **0.1.0 - Now includes actions!**
 - 0.0.2 - Now automatically sets interval based on video length. Sends useful output to Mattermost including filename, duration, file size, and format
 - 0.0.1 - Initial release