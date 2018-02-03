# mattermost-video-preview

This Ruby script will generate preview images and clips for video files using the `ffmpeg` utility. By default it will generate a 5x6 grid of images from every 1 second of video, with each image being 120px tall. For example:


![An example of the generated image](https://i.imgur.com/pY4O1Tm.jpg "An example of the generated image")


This will (eventually) be posted to a Mattermost channel so people there can see the content of the video that's been added. These previews can have a variety of uses, for example:

 - Reviewing user-generated video as it's being generated
 - Curating a video library
 - Creating preview images for posting on a website automatically

## Dependencies

This script uses the fantastic [RestClient](https://github.com/rest-client/rest-client) and [MediaInfo](https://github.com/greatseth/mediainfo) gems. You'll need to install those, as well as the `mediainfo` command line utility.

```
# gem install rest-client medianfo
```

## Usage Instructions

First, create the file `video_preview_config.yaml` using `video_preview_config.example.yaml` as an example.

Next, call the script and pass the video file as the first parameter. For example

```
$ mattermost-video-preview.rb video_file.mp4
```

This will put a message to the specified channel showing that the file was found.

![An example of the message posted](https://i.imgur.com/BWkSdPT.png "An example of the message posted")

Once this is done it will eventually put the image in the channel.

A couple ideas for using this:

 - Post-process file uploads from your web app
 - Monitor a fileserver directory using something like [incron](http://inotify.aiken.cz/?section=incron&page=about&lang=en) to generate thumbnails automatically

## Version History

 - **0.0.1 - Initial release**

## Future Features

1. Posting image file to Mattermost
2. Specifying time interval, image dimensions, and grid size via arguments
3. Add filename and date of render to images
4. Detect video length and automatically 
5. Generating a preview video rather than images
6. Add the ability to trigger other webhooks for post-processing images