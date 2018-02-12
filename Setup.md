# Setting up mattermost-video-preview

*Note:* These instructions are for Ubuntu 17.10. If you got it working on another platform please submit a pull request!

## Dependencies

The first thing you'll need to do is install the various dependences.

```
$ sudo apt install ffmpeg mediainfo webhook incron
```

Then install the publicly available Ruby Gems:

```
$ sudo gem install rest-client digest syslog-logger
```

Next, check out and install the mediainfo gem


```
$ git clone https://github.com/icelander/mediainfo.git
$ cd mediainfo
$ gem build mediainfo.gemspec
$ sudo gem install mediainfo-0.7.4.gem
```

Now you're ready to check out the main project

```
$ cd ~/
$ git clone https://github.com/icelander/mattermost-video-preview.git
$ cd mattermost-video-preview
$ cp video_preview_config.example.yaml video_preview_config.yaml
```

Now edit the `video_preview_config.yaml` file to match your specific configuration. To test it, run the following command:

```
$ ./mattermost-video-preview.rb preview clouds.mov
```

You should see something like this in your Mattermost channel

![Sample output](https://i.imgur.com/CDxQ6JF.jpg)

Now that you've got that running properly, set up your webhook to respond to the commands. First, edit the `webhook.example.conf` file to match the paths in the `video_preview_config.yaml` Once that's done install it and activate the webhook:


```
$ sudo cp webhook.example.conf /etc/webhook.conf
$ sudo service webhook restart
```

To enable directory watching you'll need to set up `incron`. To do that you need to add your user to the `incron.allow` file:

```
$ sudo echo $USER >> /etc/incron.allow
```

Next, run `incrontab -e` to edit the incron table and add this:

```
/directory/to/watch IN_CREATE /path/to/mattermost-video-preview/mattermost-video-preview.rb preview $@/$#
```

Make sure you change the paths to reflect your configuration.

Now to test it, drop a video file in your watch directory and make sure it's working. You should get the same screen shot as before.