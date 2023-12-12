# Elibri Watermarking

## Description

This library implements [Elibri Watermarking API](https://www.elibri.com.pl/doc/watermarking/api) in ruby.

## Usage

First, include `elibri_watermarking` in your Gemgile

Next, initialise the client: 

```ruby
client = ElibriWatermarking::Client.new('token', 'secret')
```

Available methods:

* watermark - registers transaction
* deliver - commits transaction
* available_files - a list of all available products
* soon_available_files - a list of soon available products
* soon_unavailable_files - a list of soon expiring products
* new_complaint - files a complains or cancelation
